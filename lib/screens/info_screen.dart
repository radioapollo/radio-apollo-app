/* Info Screen

   This screen provides general information about the radio station.

   It includes:
   - a description of the station
   - a list of sponsors loaded from Firestore
*/

import 'package:flutter/material.dart';
import '../models/sponsor.dart';
import '../services/info_services.dart';
import '../widgets/page_with_header.dart';

class InfoScreen extends StatelessWidget {
  InfoScreen({super.key});

  final _infoService = InfoService();

  static const _aboutText =
      'Radio Apollo staat voor feel-good muziek, lokale verbondenheid en een warme sfeer. '
      'We brengen een mix van classics, hedendaagse hits en lokale informatie.\n\n'
      'Onze missie is om luisteraars plezier, nieuws en gezelligheid te brengen – altijd en overal.';

  @override
  Widget build(BuildContext context) {
    return PageWithHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Over Radio Apollo',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 15),
          _buildInfoCard(),
          const SizedBox(height: 30),
          const Text('Sponsors',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 15),
          StreamBuilder<List<Sponsor>>(
            stream: _infoService.sponsorsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF102F52)));
              }
              if (snapshot.hasError) {
                return const Text('Fout bij het laden van sponsors.',
                    style: TextStyle(color: Colors.black54));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('Geen sponsors gevonden.',
                    style: TextStyle(color: Colors.black54));
              }
              return Column(
                children: snapshot.data!.map(_buildSponsorCard).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF102F52),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12, width: 1.5),
        ),
        child: const Text(_aboutText,
            style: TextStyle(color: Colors.white70, height: 1.4)),
      );

  Widget _buildSponsorCard(Sponsor sponsor) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12, width: 1.5),
        ),
        child: Row(
          children: [
            /*
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: sponsor.imageUrl != null
                  ? Image.network(sponsor.imageUrl!,
                      width: 50, height: 50, fit: BoxFit.cover)
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E0A1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.star,
                          color: Colors.black87, size: 26),
                    ),
            ),
            */
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sponsor.title,
                      style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(sponsor.description,
                      style: const TextStyle(
                          color: Colors.black54, height: 1.3, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
}