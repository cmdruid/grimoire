use grimoire_core::{
    plan, project_tree, DesiredEdit, DesiredState, Plan, PlanningMode, Request, Result, Scope,
    TreeItem, TreeItemKey, TreeProjection, WorldState,
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
            self.desired.clone().into_request(),
            PlanningMode::Normal,
        )?;
        self.cursor = self.cursor.min(self.tree.items.len().saturating_sub(1));
        Ok(())
    }

    fn cancel(&mut self) -> Result<()> {
        self.desired = DesiredState::from_world(&self.world);
        self.refresh()
    }
}

/// Pure UI state for two independently staged scopes.
pub struct TuiModel {
    project: Option<ScopeState>,
    global: Option<ScopeState>,
    active: ActiveScope,
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
            },
            ActiveScope::Global => Self {
                project: None,
                global: Some(state),
                active,
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

    pub fn plan_bytes(&self) -> Result<Vec<u8>> {
        self.plan().to_bytes()
    }

    pub fn selected_item(&self) -> Option<&TreeItem> {
        let state = self.active_state();
        state.tree.items.get(state.cursor)
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
        if height == 0 {
            state.scroll = state.cursor;
        } else if state.cursor < state.scroll {
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
        self.active_state_mut().cancel()
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
