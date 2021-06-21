import 'package:flutter/material.dart';
import 'chat.dart';

void main() {
  runApp(MyApp());
}

//Main App class
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "FAQ Chatbot",
        theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.orange[200],
            accentColor: Colors.orange[100],
            ),
        home: HomePage(title: 'FAQ Dialogflow-Flutter agent'),
    );
  }
}

// Main Screen with the Appbar and the Chat Widget
class HomePage extends StatefulWidget {
  HomePage({required this.title});

  final String title;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text(widget.title)
        ),
        body: Center(
            child: Chat()
        )
    );
  }
}
