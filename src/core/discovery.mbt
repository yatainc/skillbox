///|
/// Host-neutral file kinds; core does not import any filesystem package.
pub(all) enum EntryKind {
  Directory
  Regular
  Other
}

///|
/// The mounted host implements I/O and path semantics. All traversal,
/// candidate selection, de-duplication and parsing are performed by core.
pub(all) struct FsHost {
  exists : async (String) -> Bool
  read_dir : async (String) -> Array[String]
  kind : async (String) -> EntryKind
  realpath : async (String) -> String
  read_file : async (String) -> String
  join : (String, String) -> String
}

///|
priv struct Discovery {
  skills : Array[Skill]
  diagnostics : Array[String]
}

///|
/// Diagnostics survive even when merging two mounted catalogs fails.
pub(all) struct CatalogLoad {
  skills : Result[Array[Skill], String]
  diagnostics : Array[String]
}

///|
/// Discover SKILL.md files below one mounted root, following directory links
/// but visiting each real directory and file only once. An invalid file is
/// reported and skipped without losing other skills.
async fn discover(fs : FsHost, root : String) -> Discovery {
  let found : Array[Skill] = []
  let diagnostics : Array[String] = []
  if !(fs.exists)(root) {
    return { skills: found, diagnostics, }
  }
  let dirs = [root]
  let visited : Set[String] = Set([])
  let files : Set[String] = Set([])
  while dirs.pop() is Some(dir) {
    let physical = (fs.realpath)(dir) catch {
      _ => {
        diagnostics.push("cannot resolve directory: " + dir)
        continue
      }
    }
    if visited.contains(physical) {
      continue
    }
    visited.add(physical)
    let entries = (fs.read_dir)(dir) catch {
      _ => {
        diagnostics.push("cannot read directory: " + dir)
        continue
      }
    }
    entries.sort_by(lexical_compare)
    for name in entries {
      let path = (fs.join)(dir, name)
      let kind = (fs.kind)(path) catch {
        _ => {
          diagnostics.push("cannot inspect skill path: " + path)
          continue
        }
      }
      if kind is Directory {
        dirs.push(path)
      } else if name == "SKILL.md" && kind is Regular {
        let real = (fs.realpath)(path) catch {
          _ => {
            diagnostics.push("cannot resolve skill: " + path)
            continue
          }
        }
        if files.contains(real) {
          continue
        }
        files.add(real)
        let text = (fs.read_file)(path) catch {
          _ => {
            diagnostics.push("cannot read skill: " + path)
            continue
          }
        }
        match parse_skill_checked(path, text) {
          Ok(skill) => found.push(skill)
          Err(message) => diagnostics.push(message)
        }
      }
    }
  }
  { skills: found, diagnostics, }
}

///|
/// Search roots in priority order. Each root is one group for duplicate-name
/// validation; files in a lower-priority root cannot replace earlier skills.
pub async fn load_skills(
  fs : FsHost,
  roots_by_priority : Array[String],
) -> CatalogLoad {
  let groups_by_priority : Array[Array[Skill]] = []
  let diagnostics : Array[String] = []
  for root in roots_by_priority {
    let discovered = discover(fs, root)
    groups_by_priority.push(discovered.skills)
    for message in discovered.diagnostics {
      diagnostics.push(message)
    }
  }
  { skills: merge_skills(groups_by_priority), diagnostics, }
}
