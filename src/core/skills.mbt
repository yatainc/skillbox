///|
pub(all) struct Skill {
  name : String
  description : String
  path : String
}

///|
/// Optional convenience form for callers that intentionally skip invalid files.
pub fn parse_skill(path : String, source : String) -> Skill? {
  match parse_skill_checked(path, source) {
    Ok(skill) => Some(skill)
    Err(_) => None
  }
}

///|
/// Parse only YAML front matter, not the Markdown body. Errors contain the path.
pub fn parse_skill_checked(
  path : String,
  source : String,
) -> Result[Skill, String] {
  let source = if source.has_prefix("\u{feff}") {
    source[1:].to_owned()
  } else {
    source
  }
  let lines = source.split("\n").to_array()
  if lines.length() == 0 || (lines[0] != "---" && lines[0] != "---\r") {
    return Err(path + ": missing opening ---")
  }
  let mut closing = -1
  for i in 1..<lines.length() {
    // Indented `---` belongs to a YAML block scalar; only a column-zero
    // delimiter closes the front matter.
    if lines[i] == "---" || lines[i] == "---\r" {
      closing = i
      break
    }
  }
  if closing < 0 {
    return Err(path + ": missing closing ---")
  }
  let header = lines[1:closing].map(fn(line) { line.to_owned() }).join("\n")
  let docs = @yaml.Yaml::load_from_string("---\n" + header + "\n") catch {
    _ => return Err(path + ": invalid YAML")
  }
  if docs.length() != 1 {
    return Err(path + ": expected one YAML document")
  }
  match docs[0] {
    Map(fields) => {
      let name = match fields.get("name") {
        Some(String(s)) if s.trim() != "" => s
        _ => return Err(path + ": name must be a nonempty string")
      }
      let description = match fields.get("description") {
        Some(String(s)) if s.trim() != "" => s
        _ => return Err(path + ": description must be a nonempty string")
      }
      Ok({ name, description, path, })
    }
    _ => Err(path + ": front matter must be a mapping")
  }
}

///|
pub fn search(skills : Array[Skill], query : String) -> Array[Skill] {
  let q = query.trim().to_owned().to_lower()
  skills.filter(fn(skill) {
    q == "" ||
    skill.name.to_lower().contains(q) ||
    skill.description.to_lower().contains(q)
  })
}

///|
// Each input corresponds to the skill at the same index in the caller's array.
// The transport layer sends these inputs as one batch to classifier.dev.
pub fn recommendation_inputs(
  skills : Array[Skill],
  query : String,
) -> Array[String] {
  skills.map(fn(skill) {
    "Task: " +
    query +
    "\nSkill: " +
    skill.name +
    "\nDescription: " +
    skill.description
  })
}
