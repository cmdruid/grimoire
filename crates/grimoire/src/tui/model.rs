use grimoire_core::{
    plan, project_tree, resolve_manifest, source_key_for_alias, Approval, Blocker, DesiredEdit,
    DesiredState, Plan, PlanningMode, Request, Result, Scope, SourceAlias, SourceKey, TreeItem,
    TreeItemKey, TreeProjection, TrustBaseline, WorldState,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ActiveScope {
    Project,
    Global,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScopeRemedy {
    FindOrInitializeProject,
    InitializeProject,
    InitializeGlobal,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Dialog {
    ConfirmDestructive,
    ConfirmTrustAll {
        alias: SourceAlias,
        source_key: SourceKey,
        baseline: TrustBaseline,
    },
    Blocked {
        blockers: Vec<Blocker>,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Effect {
    Apply {
        scope: Scope,
        plan: Plan,
        approval: Approval,
    },
    Fetch {
        scope: Scope,
        alias: SourceAlias,
    },
    Update {
        scope: Scope,
        alias: SourceAlias,
        plan: Plan,
        approval: Approval,
    },
    TrustAll {
        scope: Scope,
        alias: SourceAlias,
        plan: Plan,
    },
    Quit,
}

struct ScopeState {
    world: WorldState,
    desired: DesiredState,
    tree: TreeProjection,
    plan: Plan,
    cursor: usize,
    scroll: usize,
}

impl ScopeState {
    fn new(world: WorldState) -> Result<Self> {
        let desired = DesiredState::from_world(&world);
        let tree = project_tree(&world, &desired)?;
        let plan = plan(
            &world,
            if world.manifest_present && world.lock_present {
                desired.clone().into_request()
            } else {
                Request::Initialize
            },
            PlanningMode::Normal,
        )?;
        Ok(Self {
            world,
            desired,
            tree,
            plan,
            cursor: 0,
            scroll: 0,
        })
    }

    fn refresh(&mut self) -> Result<()> {
        self.tree = project_tree(&self.world, &self.desired)?;
        self.plan = plan(
            &self.world,
            if self.world.manifest_present && self.world.lock_present {
                self.desired.clone().into_request()
            } else {
                Request::Initialize
            },
            PlanningMode::Normal,
        )?;
        self.cursor = self.cursor.min(self.tree.items.len().saturating_sub(1));
        Ok(())
    }

    fn cancel(&mut self) -> Result<()> {
        self.desired = DesiredState::from_world(&self.world);
        self.refresh()
    }

    fn is_staged(&self) -> bool {
        self.desired != DesiredState::from_world(&self.world)
    }
}

/// Pure UI state for two independently staged scopes.
pub struct TuiModel {
    project: Option<ScopeState>,
    global: Option<ScopeState>,
    active: ActiveScope,
    dialog: Option<Dialog>,
    pending: Option<Effect>,
    busy: bool,
    status: Option<String>,
}

impl TuiModel {
    pub fn new(world: WorldState) -> Result<Self> {
        let active = match world.scope {
            Scope::Project => ActiveScope::Project,
            Scope::Global => ActiveScope::Global,
        };
        let state = ScopeState::new(world)?;
        Ok(match active {
            ActiveScope::Project => Self {
                project: Some(state),
                global: None,
                active,
                dialog: None,
                pending: None,
                busy: false,
                status: None,
            },
            ActiveScope::Global => Self {
                project: None,
                global: Some(state),
                active,
                dialog: None,
                pending: None,
                busy: false,
                status: None,
            },
        })
    }

    pub fn from_scopes(project: Option<WorldState>, global: WorldState) -> Result<Self> {
        let project = project.map(ScopeState::new).transpose()?;
        let active = if project.is_some() {
            ActiveScope::Project
        } else {
            ActiveScope::Global
        };
        Ok(Self {
            project,
            global: Some(ScopeState::new(global)?),
            active,
            dialog: None,
            pending: None,
            busy: false,
            status: None,
        })
    }

    pub fn active_scope(&self) -> ActiveScope {
        self.active
    }

    pub fn switch_scope(&mut self) {
        self.active = match self.active {
            ActiveScope::Project if self.global.is_some() => ActiveScope::Global,
            ActiveScope::Global if self.project.is_some() => ActiveScope::Project,
            current => current,
        };
    }

    pub fn project_remedy(&self) -> Option<ScopeRemedy> {
        match &self.project {
            None => Some(ScopeRemedy::FindOrInitializeProject),
            Some(project) if !project.world.manifest_present => {
                Some(ScopeRemedy::InitializeProject)
            }
            Some(_) => None,
        }
    }

    pub fn global_remedy(&self) -> Option<ScopeRemedy> {
        self.global.as_ref().and_then(|global| {
            (!global.world.manifest_present).then_some(ScopeRemedy::InitializeGlobal)
        })
    }

    pub fn active_tree(&self) -> &TreeProjection {
        &self.active_state().tree
    }

    pub fn tree(&self) -> &TreeProjection {
        self.active_tree()
    }

    pub fn plan(&self) -> &Plan {
        &self.active_state().plan
    }

    /// Returns the core request represented by the active scope's staged state.
    pub fn staged_request(&self) -> Request {
        let state = self.active_state();
        if state.world.manifest_present && state.world.lock_present {
            state.desired.clone().into_request()
        } else {
            Request::Initialize
        }
    }

    pub fn plan_bytes(&self) -> Result<Vec<u8>> {
        self.plan().to_bytes()
    }

    pub fn selected_item(&self) -> Option<&TreeItem> {
        let state = self.active_state();
        state.tree.items.get(state.cursor)
    }

    pub fn selected_source(&self) -> Option<SourceAlias> {
        match &self.selected_item()?.key {
            TreeItemKey::Source(alias)
            | TreeItemKey::Pack { source: alias, .. }
            | TreeItemKey::PackMember { source: alias, .. }
            | TreeItemKey::Skill { source: alias, .. } => Some(alias.clone()),
            TreeItemKey::InheritedSkill { .. } => None,
        }
    }

    pub fn select_next(&mut self) {
        let state = self.active_state_mut();
        if !state.tree.items.is_empty() {
            state.cursor = (state.cursor + 1).min(state.tree.items.len() - 1);
        }
    }

    pub fn select_previous(&mut self) {
        let state = self.active_state_mut();
        state.cursor = state.cursor.saturating_sub(1);
    }

    pub fn keep_selection_visible(&mut self, height: usize) {
        let state = self.active_state_mut();
        if height == 0 || state.cursor < state.scroll {
            state.scroll = state.cursor;
        } else if state.cursor >= state.scroll + height {
            state.scroll = state.cursor + 1 - height;
        }
    }

    pub fn visible_items(&self, height: usize) -> &[TreeItem] {
        let state = self.active_state();
        let start = state.scroll.min(state.tree.items.len());
        let end = (start + height).min(state.tree.items.len());
        &state.tree.items[start..end]
    }

    pub fn toggle(&mut self, key: &TreeItemKey) -> Result<()> {
        let state = self.active_state_mut();
        let item = state
            .tree
            .item(key)
            .filter(|item| item.toggleable)
            .cloned()
            .ok_or_else(|| {
                grimoire_core::CoreError::Request("tree item is not toggleable".into())
            })?;
        let edit = match key {
            TreeItemKey::Skill { source, name } => DesiredEdit::SetSkill {
                name: name.clone(),
                source: source.clone(),
                enabled: !item.selected,
            },
            TreeItemKey::Pack { source, name } => DesiredEdit::SetPack {
                name: name.clone(),
                source: source.clone(),
                enabled: !item.selected,
            },
            TreeItemKey::PackMember { pack, name, .. } => DesiredEdit::SetPackOptional {
                pack: pack.clone(),
                skill: name.clone(),
                enabled: !item.selected,
            },
            TreeItemKey::Source(_) | TreeItemKey::InheritedSkill { .. } => {
                return Err(grimoire_core::CoreError::Request(
                    "tree item is not toggleable".into(),
                ))
            }
        };
        state.desired.apply(edit)?;
        state.refresh()
    }

    pub fn toggle_selected(&mut self) -> Result<()> {
        let key = self
            .selected_item()
            .map(|item| item.key.clone())
            .ok_or_else(|| grimoire_core::CoreError::Request("tree is empty".into()))?;
        self.toggle(&key)
    }

    pub fn cancel(&mut self) -> Result<()> {
        self.dialog = None;
        self.pending = None;
        self.active_state_mut().cancel()
    }

    pub fn is_staged(&self) -> bool {
        self.active_state().is_staged()
    }

    pub fn dialog(&self) -> Option<&Dialog> {
        self.dialog.as_ref()
    }

    pub fn dialog_plan(&self) -> Option<&Plan> {
        match self.pending.as_ref()? {
            Effect::Apply { plan, .. }
            | Effect::Update { plan, .. }
            | Effect::TrustAll { plan, .. } => Some(plan),
            Effect::Fetch { .. } | Effect::Quit => None,
        }
    }

    pub fn is_busy(&self) -> bool {
        self.busy
    }

    pub fn status(&self) -> Option<&str> {
        self.status.as_deref()
    }

    pub fn set_busy(&mut self, busy: bool) {
        self.busy = busy;
        if busy {
            self.status = None;
        }
    }

    pub fn set_status(&mut self, status: impl Into<String>) {
        self.busy = false;
        self.status = Some(status.into());
    }

    pub fn request_apply(&mut self) -> Option<Effect> {
        let state = self.active_state();
        if !state.plan.blockers.is_empty() {
            self.dialog = Some(Dialog::Blocked {
                blockers: state.plan.blockers.clone(),
            });
            self.pending = None;
            return None;
        }
        if state.plan.is_destructive() {
            self.dialog = Some(Dialog::ConfirmDestructive);
            self.pending = Some(self.apply_effect(Approval::Granted));
            return None;
        }
        Some(self.apply_effect(Approval::NotRequired))
    }

    pub fn request_trust_all(&mut self, alias: SourceAlias) -> Result<Option<Effect>> {
        let state = self.active_state();
        let trust = plan(
            &state.world,
            Request::TrustSource {
                alias: alias.clone(),
                mode: grimoire_core::SourceTrustIntent::All,
            },
            PlanningMode::Normal,
        )?;
        if !trust.blockers.is_empty() {
            self.dialog = Some(Dialog::Blocked {
                blockers: trust.blockers.clone(),
            });
            self.pending = None;
            return Ok(None);
        }
        let candidate = state.world.candidates.get(&alias).ok_or_else(|| {
            grimoire_core::CoreError::Source(format!("source `{alias}` has no candidate to trust"))
        })?;
        let source_key = source_key_for_alias(&state.world, &alias)?;
        let baseline = TrustBaseline {
            commit: candidate.snapshot.id.commit.clone(),
            tree: candidate.snapshot.id.tree.clone(),
            inventory: candidate.snapshot.id.inventory_digest.clone(),
            review_tree: candidate
                .review_tree
                .clone()
                .unwrap_or_else(|| candidate.snapshot.inventory.review_tree_digest.to_string()),
        };
        self.pending = Some(Effect::TrustAll {
            scope: self.scope(),
            alias: alias.clone(),
            plan: trust,
        });
        self.dialog = Some(Dialog::ConfirmTrustAll {
            alias,
            source_key,
            baseline,
        });
        Ok(None)
    }

    pub fn request_fetch(&self, alias: SourceAlias) -> Effect {
        Effect::Fetch {
            scope: self.scope(),
            alias,
        }
    }

    pub fn request_update(&mut self, alias: SourceAlias) -> Result<Option<Effect>> {
        let update = plan(
            &self.active_state().world,
            Request::UpdateSource {
                alias: alias.clone(),
            },
            PlanningMode::Normal,
        )?;
        if !update.blockers.is_empty() {
            self.dialog = Some(Dialog::Blocked {
                blockers: update.blockers.clone(),
            });
            self.pending = None;
            return Ok(None);
        }
        let effect = Effect::Update {
            scope: self.scope(),
            alias,
            approval: if update.is_destructive() {
                Approval::Granted
            } else {
                Approval::NotRequired
            },
            plan: update,
        };
        if matches!(
            effect,
            Effect::Update {
                approval: Approval::Granted,
                ..
            }
        ) {
            self.dialog = Some(Dialog::ConfirmDestructive);
            self.pending = Some(effect);
            Ok(None)
        } else {
            Ok(Some(effect))
        }
    }

    pub fn confirm(&mut self, accepted: bool) -> Option<Effect> {
        match self.dialog.take()? {
            Dialog::ConfirmDestructive | Dialog::ConfirmTrustAll { .. } if accepted => {
                self.pending.take()
            }
            Dialog::ConfirmDestructive | Dialog::ConfirmTrustAll { .. } => {
                self.pending = None;
                None
            }
            Dialog::Blocked { .. } => None,
        }
    }

    pub fn request_quit(&mut self) -> Result<Effect> {
        if let Some(project) = self.project.as_mut() {
            project.cancel()?;
        }
        if let Some(global) = self.global.as_mut() {
            global.cancel()?;
        }
        self.dialog = None;
        self.pending = None;
        Ok(Effect::Quit)
    }

    pub fn accept_reloaded_scope(&mut self, world: WorldState) -> Result<()> {
        let scope = world.scope;
        let inherited =
            (scope == Scope::Global).then(|| resolve_manifest(&world.manifest, &world.snapshots));
        let state = ScopeState::new(world)?;
        match scope {
            Scope::Project => self.project = Some(state),
            Scope::Global => {
                self.global = Some(state);
                if let Some(project) = self.project.as_mut() {
                    project.world.inherited_global = inherited;
                    project.refresh()?;
                }
            }
        }
        self.dialog = None;
        self.pending = None;
        Ok(())
    }

    fn scope(&self) -> Scope {
        match self.active {
            ActiveScope::Project => Scope::Project,
            ActiveScope::Global => Scope::Global,
        }
    }

    fn apply_effect(&self, approval: Approval) -> Effect {
        Effect::Apply {
            scope: self.scope(),
            plan: self.active_state().plan.clone(),
            approval,
        }
    }

    fn active_state(&self) -> &ScopeState {
        match self.active {
            ActiveScope::Project => self.project.as_ref().expect("active project scope"),
            ActiveScope::Global => self.global.as_ref().expect("active global scope"),
        }
    }

    fn active_state_mut(&mut self) -> &mut ScopeState {
        match self.active {
            ActiveScope::Project => self.project.as_mut().expect("active project scope"),
            ActiveScope::Global => self.global.as_mut().expect("active global scope"),
        }
    }
}
