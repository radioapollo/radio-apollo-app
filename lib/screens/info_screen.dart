/* Info Screen

   This screen provides general information about the radio station.

   It includes:
   - a description of the station
   - sponsor information
   - announcements or promotional content
*/

import 'package:flutter/material.dart';
import '../models/sponsor.dart';
import '../services/info_services.dart';
import '../widgets/page_with_header.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final infoService = InfoService();

    return PageWithHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Over Radio Apollo",
            style: TextStyle(
              color: Colors.black,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 15),
          _buildInfoCard(),
          const SizedBox(height: 30),
          const Text(
            "Sponsors",
            style: TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 15),
          ...infoService.sponsors.map((s) => _buildSponsorCard(s)),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102F52),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 1.5),
      ),
      child: const Text(
        "Radio Apollo staat voor feel-good muziek, lokale verbondenheid en een warme sfeer. "
        "We brengen een mix van classics, hedendaagse hits en lokale informatie.\n\n"
        "Onze missie is om luisteraars plezier, nieuws en gezelligheid te brengen – altijd en overal.",
        style: TextStyle(color: Colors.white70, height: 1.4),
      ),
    );
  }

  Widget _buildSponsorCard(Sponsor sponsor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E0A1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.star, color: Colors.black87, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sponsor.title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sponsor.description,
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.3,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}