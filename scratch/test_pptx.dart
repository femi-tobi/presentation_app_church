import 'package:dart_pptx/dart_pptx.dart';

void main() async {
  final pres = PowerPoint();
  print('Powerpoint instantiated successfully!');
  
  // Test slide addition
  pres.addTitleSlide(
    title: 'Hello World'.toTextValue(),
    author: 'Developer'.toTextValue(),
  );
  
  pres.addTitleAndBulletsSlide(
    title: 'Slide 2'.toTextValue(),
    subtitle: 'This is a test subtitle'.toTextValue(),
    bullets: [
      'Bullet 1'.toTextValue(),
      'Bullet 2'.toTextValue(),
    ],
  );

  final bytes = await pres.save();
  print('Presentation bytes generated: ${bytes?.length} bytes');
}
