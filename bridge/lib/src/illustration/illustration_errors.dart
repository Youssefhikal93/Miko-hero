/// Machine-readable reason one illustration job or page did not succeed.
///
/// Like the story codes, these are the only rendering detail that is ever
/// logged or handed to a paired device. Scene descriptions, prompts and image
/// bytes never are.
enum IllustrationFailureCode {
  /// The local ComfyUI server could not be reached or refused the call.
  comfyUiUnavailable('comfyui_unavailable'),

  /// ComfyUI did not finish the render within the configured timeout.
  comfyUiTimeout('comfyui_timeout'),

  /// ComfyUI accepted the workflow and then reported it as failed.
  comfyUiFailed('comfyui_failed'),

  /// ComfyUI reported success but returned nothing usable as a PNG.
  invalidImageOutput('invalid_image_output'),

  /// The rendered image could not be written into the library folder.
  imageWriteFailed('image_write_failed'),

  /// The illustration row could not be updated after a successful render.
  libraryWriteFailed('library_write_failed'),

  /// The job was cancelled before every page was rendered.
  cancelled('cancelled'),

  /// An unexpected bridge-side failure aborted the job.
  internalError('internal_error');

  const IllustrationFailureCode(this.wireCode);

  /// Stable snake_case code used in JSON payloads and log lines.
  final String wireCode;
}

/// Terminal failure attached to a failed illustration job.
class IllustrationFailure {
  /// Creates a failure from a stable [code] and a safe [message].
  const IllustrationFailure({required this.code, required this.message});

  /// Machine-readable reason for the failure.
  final IllustrationFailureCode code;

  /// Human-readable explanation that never contains scene text, prompts,
  /// file paths or image bytes.
  final String message;

  /// JSON shape embedded in job status responses.
  Map<String, Object?> toJson() {
    return <String, Object?>{'code': code.wireCode, 'message': message};
  }
}

/// Exception raised inside the illustration pipeline.
///
/// Every layer (the ComfyUI call, the image check, the library write) reports
/// its failures as this type so the job engine only reasons about typed codes.
class IllustrationException implements Exception {
  /// Creates an exception carrying a typed [code] and a safe [message].
  const IllustrationException(this.code, this.message);

  /// Machine-readable reason for the failure.
  final IllustrationFailureCode code;

  /// Safe explanation; never echoes prompts or image data.
  final String message;

  /// Converts this exception into the failure stored on a job.
  IllustrationFailure toFailure() {
    return IllustrationFailure(code: code, message: message);
  }

  @override
  String toString() => 'IllustrationException(${code.wireCode})';
}
