/* Sponsor Model
 
   This file defines the structure of a sponsor of the radio station.
 
   It contains:
   - the sponsor name
   - a description or promotional text
   - an optional image URL for the sponsor logo (photo is not ready yet.)
*/
 
class Sponsor {
  final String title;
  final String description;
  final String? imageUrl;
 
  const Sponsor({
    required this.title,
    required this.description,
    this.imageUrl,
  });
}