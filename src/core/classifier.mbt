///|
let direct_label = "directly applicable to the explicit user request"

///|
let other_label = "not directly applicable to the explicit user request"

///|
/// A transport-independent POST request. The caller supplies the base URL
/// (normally https://classifier.dev) and performs the actual network I/O.
pub(all) struct ClassifierRequest {
  path : String
  content_type : String
  body : String
}

///|
pub(all) struct Recommendation {
  skill : Skill
  confidence : Double?
  relevance : Double?
}

///|
/// One batch maps results back to skills by position. The caller must not
/// reorder the skills between preparing and decoding the request.
pub fn classifier_request(
  skills : Array[Skill],
  query : String,
) -> Result[ClassifierRequest, String] {
  if query.trim() == "" {
    return Err("query must not be empty")
  }
  if skills.length() == 0 {
    return Err("no skills; do not send an empty request")
  }
  if skills.length() > 1000 {
    return Err("more than 1000 skills; split into batches")
  }
  let inputs = recommendation_inputs(skills, query)
  for input in inputs {
    if input.char_length() > 32000 {
      return Err("classification input exceeds 32000 characters")
    }
  }
  let instructions = "Choose directly applicable ONLY if the skill description explicitly covers the task requested by the user. " +
    "Generic web searching, fetching URL contents, environment setup, coordination and browsing do not directly apply to programming in a language unless the user specifically requests these actions. " +
    "Do not infer additional tasks the user did not mention."
  let body = Json::object(
    Map([
      ("inputs", @json.to_json(inputs)),
      ("labels", @json.to_json([direct_label, other_label])),
      ("instructions", @json.to_json(instructions)),
    ]),
  ).stringify()
  Ok({ path: "/v1/classify", content_type: "application/json", body, })
}

///|
/// Decode a POST response without doing I/O. Retain low-confidence matches;
/// callers can inspect confidence, while ranking uses the direct-match score.
pub fn classifier_response(
  skills : Array[Skill],
  status : Int,
  body : String,
) -> Result[Array[Recommendation], String] {
  if status != 200 {
    return Err("classifier HTTP status " + status.to_string())
  }
  let data = @json.parse(body) catch {
    _ => return Err("invalid classifier JSON")
  }
  let results = match data {
    Object(fields) =>
      match fields.get("results") {
        Some(Array(items)) => items
        _ => return Err("missing classifier results")
      }
    _ => return Err("classifier response must be an object")
  }
  if results.length() != skills.length() {
    return Err("classifier result count differs from skill count")
  }
  let recommendations : Array[Recommendation] = []
  for i in 0..<results.length() {
    let (label, confidence, score) = match decode_result(results[i]) {
      Ok(value) => value
      Err(message) => return Err("result " + i.to_string() + ": " + message)
    }
    if label == direct_label {
      recommendations.push({ skill: skills[i], confidence, relevance: score, })
    }
  }
  recommendations.sort_by(compare_recommendations)
  Ok(recommendations)
}

///|
fn compare_recommendations(a : Recommendation, b : Recommendation) -> Int {
  match (a.relevance, b.relevance) {
    (Some(x), Some(y)) if x != y => if x > y { -1 } else { 1 }
    (Some(_), None) => -1
    (None, Some(_)) => 1
    _ => {
      let by_name = lexical_compare(a.skill.name, b.skill.name)
      if by_name != 0 {
        by_name
      } else {
        lexical_compare(a.skill.path, b.skill.path)
      }
    }
  }
}

///|
fn decode_result(result : Json) -> Result[(String, Double?, Double?), String] {
  let fields = match result {
    Object(fields) => fields
    _ => return Err("result must be an object")
  }
  let label = match fields.get("label") {
    Some(String(label)) if label == direct_label || label == other_label =>
      label
    _ => return Err("invalid label")
  }
  let confidence = match fields.get("confidence") {
    Some(Number(value, ..)) if value >= 0.0 && value <= 1.0 => Some(value)
    Some(Null) => None
    _ => return Err("invalid confidence")
  }
  let score = match fields.get("scores") {
    Some(Object(scores)) =>
      match scores.get(direct_label) {
        Some(Number(value, ..)) if value >= 0.0 && value <= 1.0 => Some(value)
        _ => return Err("invalid direct-match score")
      }
    Some(Null) => None
    _ => return Err("invalid scores")
  }
  Ok((label, confidence, score))
}
