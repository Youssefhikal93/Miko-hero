/// Machine-readable reason one story generation job did not succeed.
///
/// These codes are the only generation detail that is ever logged or sent to
/// a paired device; prompts, model output and child names never are.
enum GenerationFailureCode {
  /// The submitted request failed validation before any work started.
  invalidRequest('invalid_request'),

  /// The local Ollama server could not be reached or refused the call.
  ollamaUnavailable('ollama_unavailable'),

  /// Ollama did not answer within the configured generation timeout.
  ollamaTimeout('ollama_timeout'),

  /// The model answered, but its output failed structural validation on
  /// every allowed attempt.
  invalidModelOutput('invalid_model_output'),

  /// The validated story could not be written to the master library.
  libraryWriteFailed('library_write_failed'),

  /// The job was cancelled before it completed.
  cancelled('cancelled'),

  /// An unexpected bridge-side failure aborted the job.
  internalError('internal_error');

  const GenerationFailureCode(this.wireCode);

  /// Stable snake_case code used in JSON payloads and log lines.
  final String wireCode;
}

/// Terminal failure attached to a failed job.
class GenerationFailure {
  /// Creates a failure from a stable [code] and a safe [message].
  const GenerationFailure({required this.code, required this.message});

  /// Machine-readable reason for the failure.
  final GenerationFailureCode code;

  /// Human-readable explanation that never contains story content, prompts,
  /// child names or model output.
  final String message;

  /// JSON shape embedded in job status responses.
  Map<String, Object?> toJson() {
    return <String, Object?>{'code': code.wireCode, 'message': message};
  }
}

/// Exception raised inside the generation pipeline.
///
/// Every layer (HTTP call, output validation, persistence) converts its own
/// failures into this type so the job engine only has to reason about typed
/// codes.
class GenerationException implements Exception {
  /// Creates an exception carrying a typed [code] and a safe [message].
  const GenerationException(this.code, this.message);

  /// Machine-readable reason for the failure.
  final GenerationFailureCode code;

  /// Safe explanation; never echoes prompts or model output.
  final String message;

  /// Converts this exception into the failure stored on a job.
  GenerationFailure toFailure() {
    return GenerationFailure(code: code, message: message);
  }

  @override
  String toString() => 'GenerationException(${code.wireCode})';
}
