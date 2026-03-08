/* Sponsor Model
   This file represents a sponsor of the radio station.

   It stores information about sponsors, including:
   - the sponsor name
   - a description or promotional text
*/

class Sponsor {
  final String title;
  final String description;

  const Sponsor({
    required this.title,
    required this.description,
  });
}