/* Event Model
   This file defines the structure of an event used in the application.

   It describes what data an event contains, such as:
   - the title of the event
   - the date it takes place
   - the location of the event
   - a description of what the event is about
*/

class Event {
  final String title;
  final String date;
  final String location;
  final String what;

  Event({
    required this.title,
    required this.date,
    required this.location,
    required this.what,
  });
}