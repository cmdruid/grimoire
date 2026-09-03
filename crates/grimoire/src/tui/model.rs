use grimoire_core::{
    plan, project_tree, DesiredEdit, DesiredState, Plan, PlanningMode, Result, TreeItemKey,
    TreeProjection, WorldState,
};

/// Pure TUI state. The observed world never changes while edits are staged.
pub struct TuiModel {
    world: WorldState,
    desired: DesiredState,
    tree: TreeProjection,
    plan: Plan,
}

impl TuiModel {
    pub fn new(world: WorldState) -> Result<Self> {
        let desired = DesiredState::from_world(&world);
        let tree = project_tree(&world, &desired)?;
        let plan = plan(&world, desired.clone().into_request(), PlanningMode::Normal)?;
        Ok(Self {
            world,
            desired,
            tree,
            plan,
        })
    }

    pub fn tree(&self) -> &TreeProjection {
        &self.tree
    }

    pub fn plan(&self) -> &Plan {
        &self.plan
    }

    pub fn plan_bytes(&self) -> Result<Vec<u8>> {
        self.plan.to_bytes()
    }

    pub fn toggle(&mut self, key: &TreeItemKey) -> Result<()> {
        let item = self
            .tree
            .item(key)
            .filter(|item| item.toggleable)
            .ok_or_else(|| {
                grimoire_core::CoreError::Request("tree item is not toggleable".into())
            })?;
        let edit = match key {
            TreeItemKey::Skill { source, name } => DesiredEdit::SetSkill {
                name: name.clone(),
                source: source.clone(),
                enabled: !item.selected,
            },
            _ => {
                return Err(grimoire_core::CoreError::Request(
                    "tree item is not toggleable".into(),
                ))
            }
        };
        self.desired.apply(edit)?;
        self.tree = project_tree(&self.world, &self.desired)?;
        self.plan = plan(
            &self.world,
            self.desired.clone().into_request(),
            PlanningMode::Normal,
        )?;
        Ok(())
    }
}
