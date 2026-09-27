///|
// Compare UTF-16 code units for a stable lexicographic tie-breaker.
// MoonBit's built-in String ordering compares length first.
fn lexical_compare(a : String, b : String) -> Int {
  let length = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<length {
    let x = a.code_unit_at(i)
    let y = b.code_unit_at(i)
    if x < y {
      return -1
    }
    if x > y {
      return 1
    }
  }
  if a.length() < b.length() {
    -1
  } else if a.length() > b.length() {
    1
  } else {
    0
  }
}

///|
/// Look up the exact name in a catalog after source precedence is resolved.
pub fn get_skill(skills : Array[Skill], name : String) -> Skill? {
  for skill in skills {
    if skill.name == name {
      return Some(skill)
    }
  }
  None
}

///|
/// Merge groups ordered from highest to lowest priority. Duplicate names
/// within one group are errors; a name in a later group never replaces an
/// earlier one. Return skills in deterministic name order.
pub fn merge_skills(
  groups_by_priority : Array[Array[Skill]],
) -> Result[Array[Skill], String] {
  let merged : Map[String, Skill] = Map([])
  for group in groups_by_priority {
    let names : Map[String, String] = Map([])
    for skill in group {
      if names.get(skill.name) is Some(previous) {
        return Err(
          "duplicate skill " +
          skill.name +
          ": " +
          previous +
          " and " +
          skill.path,
        )
      }
      names[skill.name] = skill.path
      if merged.get(skill.name) is None {
        merged[skill.name] = skill
      }
    }
  }
  let result = merged.values().to_array()
  result.sort_by(fn(a, b) { lexical_compare(a.name, b.name) })
  Ok(result)
}
