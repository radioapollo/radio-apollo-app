/* Info Service

   This service provides data for the Info screen.

   It may handle:
   - retrieving sponsor information
   - loading announcements
   - managing station information
*/

import '../models/sponsor.dart';

class InfoService {
  final List<Sponsor> sponsors = const [
    Sponsor(title: "Café De Brug", description: "De gezelligste plek voor een pintje"),
    Sponsor(title: "Garage Peeters", description: "Onderhoud, herstellingen & topservice"),
    Sponsor(title: "Bakkerij Rose", description: "Elke dag vers brood en gebak"),
  ];

  final String aboutText = 
    "Radio Apollo staat voor feel-good muziek, lokale verbondenheid en een warme sfeer. "
    "We brengen een mix van classics, hedendaagse hits en lokale informatie.\n\n"
    "Onze missie is om luisteraars plezier, nieuws en gezelligheid te brengen – altijd en overal.";
}