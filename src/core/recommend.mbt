///|
pub(all) struct ClassifierResponse {
  status : Int
  body : String
}

///|
/// The transport-independent recommendation use case. The injected sender
/// handles HTTP and retries; the caller sets the timeout around this entire
/// operation. Empty catalogs never invoke the sender.
pub async fn recommend(
  send : async (ClassifierRequest) -> ClassifierResponse,
  skills : Array[Skill],
  query : String,
) -> Result[Array[Recommendation], String] {
  if skills.length() == 0 {
    return Ok([])
  }
  let request = match classifier_request(skills, query) {
    Ok(request) => request
    Err(message) => return Err(message)
  }
  let response = send(request)
  classifier_response(skills, response.status, response.body)
}
