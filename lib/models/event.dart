/* Event Model
 
   This file defines the structure of an event.
 
   It contains:
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
 
  const Event({
    required this.title,
    required this.date,
    required this.location,
    required this.what,
  });
}