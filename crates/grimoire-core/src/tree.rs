use crate::{DesiredState, PackName, Result, Scope, SkillName, SourceAlias, WorldState};

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub enum TreeItemKey {
    Source(SourceAlias),
    Pack {
        source: SourceAlias,
        name: PackName,
    },
    Skill {
        source: SourceAlias,
        name: SkillName,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TreeItem {
    pub key: TreeItemKey,
    pub label: String,
    pub depth: u16,
    pub selected: bool,
    pub toggleable: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TreeProjection {
    pub scope: Scope,
    pub items: Vec<TreeItem>,
}

impl TreeProjection {
    pub fn item(&self, key: &TreeItemKey) -> Option<&TreeItem> {
        self.items.iter().find(|item| &item.key == key)
    }
}

/// Project immutable source facts together with disposable desired roots.
pub fn project_tree(world: &WorldState, desired: &DesiredState) -> Result<TreeProjection> {
    let mut items = Vec::new();
    for (alias, source) in &world.source_states {
        items.push(TreeItem {
            key: TreeItemKey::Source(alias.clone()),
            label: alias.to_string(),
            depth: 0,
            selected: false,
            toggleable: false,
        });
        for skill in &source.snapshot.inventory.skills {
            let name = SkillName::new(skill.name.clone())?;
            items.push(TreeItem {
                key: TreeItemKey::Skill {
                    source: alias.clone(),
                    name: name.clone(),
                },
                label: name.to_string(),
                depth: 1,
                selected: desired.skills.get(&name) == Some(alias),
                toggleable: desired.skills.get(&name).is_none_or(|owner| owner == alias),
            });
        }
    }
    Ok(TreeProjection {
        scope: world.scope,
        items,
    })
}
