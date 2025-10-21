// lib/models/customer_details.dart
class CustomerDetails {
  final String? name;
  final String? email;
  final String? whatsapp;
  final String? address;
  final String? city;
  final String? postalCode;

  CustomerDetails({this.name, this.email, this.whatsapp, this.address, this.city, this.postalCode});

  factory CustomerDetails.fromJson(Map<String, dynamic> json) {
    return CustomerDetails(
      name: json['name'],
      email: json['email'],
      whatsapp: json['whatsapp'],
      address: json['address'],
      city: json['city'],
      postalCode: json['postalCode'],
    );
  }
}