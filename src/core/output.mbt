///|
priv struct OutputRow {
  name : String
  relevance : Double?
  path : String
}

///|
fn rows_from_skills(skills : Array[Skill]) -> Array[OutputRow] {
  skills.map(fn(skill) {
    { name: skill.name, relevance: None, path: skill.path, }
  })
}

///|
fn rows_from_recommendations(
  recommendations : Array[Recommendation],
) -> Array[OutputRow] {
  // Recommendations are sorted by classifier_response; only display five.
  let top : Array[OutputRow] = []
  for i in 0..<recommendations.length() {
    if i == 5 {
      break
    }
    let item = recommendations[i]
    top.push({
      name: item.skill.name,
      relevance: item.relevance,
      path: item.skill.path,
    })
  }
  top
}

///|
fn format_table(rows : Array[OutputRow]) -> String {
  let lines = ["name\trelevance\tpath", "----\t---------\t----"]
  for row in rows {
    let relevance = match row.relevance {
      Some(value) => value.to_string()
      None => "-"
    }
    let name = sanitize(row.name)
    let path = sanitize(row.path)
    lines.push(name + "\t" + relevance + "\t" + path)
  }
  lines.join("\n")
}

///|
fn sanitize(s : String) -> String {
  let out = StringBuilder()
  for char in s.iter() {
    let code = char.to_int()
    if code < 0x20 ||
      (code >= 0x7f && code <= 0x9f) ||
      (code >= 0x2028 && code <= 0x202e) ||
      (code >= 0x2066 && code <= 0x2069) {
      let hex = "0000" + code.to_string(radix=16).to_upper()
      out.write_string("\\u" + hex[hex.length() - 4:].to_owned())
    } else {
      out.write_char(char)
    }
  }
  out.to_string()
}

///|
fn format_json(rows : Array[OutputRow]) -> String {
  let items = rows.map(fn(row) {
    let fields : Map[String, Json] = Map([
      ("name", @json.to_json(row.name)),
      (
        "relevance",
        match row.relevance {
          Some(value) => @json.to_json(value)
          None => Json::null()
        },
      ),
      ("path", @json.to_json(row.path)),
    ])
    Json::object(fields)
  })
  Json::array(items).stringify()
}

///|
fn format_output(rows : Array[OutputRow], as_json : Bool) -> String {
  if as_json {
    format_json(rows)
  } else {
    format_table(rows)
  }
}

///|
/// A raw SKILL.md path for command-line use, or one JSON string when requested.
pub fn format_skill_path(skill : Skill, as_json : Bool) -> String {
  if as_json {
    @json.to_json(skill.path).stringify()
  } else {
    skill.path
  }
}

///|
/// Pure rendering for list and search; the host writes the returned text.
pub fn format_skills(skills : Array[Skill], as_json : Bool) -> String {
  format_output(rows_from_skills(skills), as_json)
}

///|
/// Pure rendering for the first five directly applicable recommendations.
pub fn format_recommendations(
  recommendations : Array[Recommendation],
  as_json : Bool,
) -> String {
  format_output(rows_from_recommendations(recommendations), as_json)
}
