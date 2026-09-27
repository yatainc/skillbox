///|
/// The delay is validated by core; transport errors stay distinct.
suberror ClassifierHttpError {
  HttpStatus(Int, Int?)
}

///|
fn fatal_classifier_error(error : Error) -> Bool {
  match error {
    ClassifierHttpError::HttpStatus(_, Some(_)) => false
    _ => true
  }
}

///|
/// @async.retry owns the attempt limit and cancellation. Sleep for a short
/// Retry-After only if another attempt remains.
async fn post_classifier(
  request : @core.ClassifierRequest,
  base_url : String,
) -> String {
  let headers : Map[@http.CaseInsensitiveString, String] = Map([
    (CaseInsensitiveString("content-type"), request.content_type),
  ])
  let mut pending_delay : Int? = None
  @async.retry(Immediate, max_retry=2, fatal_error=fatal_classifier_error, () => {
    if pending_delay is Some(ms) {
      @async.sleep(ms)
    }
    let (response, body) = @http.post(
      base_url + request.path,
      request.body,
      headers~,
    )
    if response.code != 200 {
      let delay = @core.retry_delay_ms(
        response.code,
        response.headers.get(CaseInsensitiveString("retry-after")),
      )
      pending_delay = delay
      raise ClassifierHttpError::HttpStatus(response.code, delay)
    }
    body.text()
  })
}

///|
/// The native sender supplies the origin, HTTP transport and retries.
/// The caller applies the time budget to the whole recommendation use case.
fn classifier_sender(
  base_url : String,
) -> async (@core.ClassifierRequest) -> @core.ClassifierResponse {
  request => {
    let (status, body) = (200, post_classifier(request, base_url)) catch {
      ClassifierHttpError::HttpStatus(status, _) => (status, "")
      error => raise error
    }
    { status, body, }
  }
}
