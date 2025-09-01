class UploadModel {
  String? eTag;
  String? key;
  String? location;

  UploadModel({
    this.eTag,
    this.key,
    this.location,
  });

  factory UploadModel.fromJson(Map<String, dynamic> json) {
    return UploadModel(
      eTag: json['ETag'] ?? "",
      key: json['key'] ?? "",
      location: json['Location'] ?? "",
    );
  }

  @override
  String toString() {
    return 'UploadModel{eTag: $eTag, key: $key, location: $location}';
  }
}
