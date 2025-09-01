class CommonResponse {
  String? code;
  String? message;
  String? additionalMessage;
  String? responseTime;
  dynamic body;

  CommonResponse({
    this.code,
    this.message,
    this.additionalMessage,
    this.responseTime,
    this.body,
  });

  CommonResponse.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    additionalMessage = json['additionalMessage'];
    responseTime = json['responseTime'];
    body = json['body'];
  }

  @override
  String toString() {
    return 'CommonResponse{code: $code, message: $message, additionalMessage: $additionalMessage, responseTime: $responseTime, body: $body}';
  }
}
