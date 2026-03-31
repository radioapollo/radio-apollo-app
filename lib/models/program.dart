/* Program Model
 
   This file defines the structure of a radio program.
 
   It contains the data needed to describe a program in the schedule:
   - the program title
   - the time it airs
   - a short description
*/
 
class Program {
  final String time;
  final String title;
  final String subtitle;
 
  const Program({
    required this.time,
    required this.title,
    required this.subtitle,
  });
}