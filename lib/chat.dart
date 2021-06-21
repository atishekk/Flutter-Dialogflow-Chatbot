import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:dialogflow_grpc/dialogflow_grpc.dart';
import 'package:dialogflow_grpc/generated/google/cloud/dialogflow/v2beta1/session.pb.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

// Chat Widget 
class Chat extends StatefulWidget {

  @override
  _ChatState createState() => _ChatState();
}

//Chat State
class _ChatState extends State<Chat> {
  //Message List
  final List<ChatMessage> _messages = <ChatMessage>[];
  //Textbox Controller
  final TextEditingController _textController = TextEditingController();

  bool _isRecording = false;

  //Get the Audio stream 
  RecorderStream _recorder = RecorderStream();
  //Subscribing to the audio stream
  late StreamSubscription _recorderStatus;
  late StreamSubscription<List<int>> _audioStreamSubscription;
  late BehaviorSubject<List<int>> _audioStream;

  //Dialogflow object
  late DialogflowGrpcV2Beta1 dialogflow;

  @override
  void initState() {
    super.initState();
    initPlugin();
  }

  @override
  void dispose() {
    _recorderStatus.cancel();
    _audioStreamSubscription.cancel();
    super.dispose();
  }

  Future<void> initPlugin() async {
    //initialise _recorderStatus to track the recording state
    _recorderStatus = _recorder.status.listen((status) {
      if(mounted) {
        setState(() {
          _isRecording = status == SoundStreamStatus.Playing;
        });
      }
    });
    //initialise the _recorder object
    await Future.wait([
      _recorder.initialize()
    ]);

    //Get the service account credentials and initialise the dialogflow object
    final serviceAccount = ServiceAccount.fromString(
        '${(await rootBundle.loadString('assets/credentials.json'))}'
    );

    dialogflow = DialogflowGrpcV2Beta1.viaServiceAccount(serviceAccount);
  }

  //Stop the recording
  void stopStream() async {
    await _recorder.stop();
    await _audioStreamSubscription.cancel();
    await _audioStream.close();
  }

  //When text is submitted
  void handleSubmitted(text) async {
    _textController.clear();

    //create the ChatMessage object and push it to _messages
    ChatMessage message = ChatMessage(
        key: Key(text),
        text: text,
        name: "You",
        type: true,
    );

    setState(() {
      _messages.insert(0, message);
    });

    //calling detectIntent on the typed text and create the botMessage ChatMessage object 
    // to be displayed in UI with the fulfillmentText returned by the service.
    DetectIntentResponse data = await dialogflow.detectIntent(text, 'en-US');
    String fulfillmentText = data.queryResult.fulfillmentText;
    if(fulfillmentText.isNotEmpty) {
      ChatMessage botMessage = ChatMessage(
          key: Key(fulfillmentText),
          text: fulfillmentText,
          name: "Bot",
          type: false,
      );

      setState(() {
        _messages.insert(0, botMessage);
      });
    }
  }

  //When question is spoken
  void handleStream() async {
    //start the recording and initialise the audio stream to listen to the incoming data
    _recorder.start();
    _audioStream = BehaviorSubject<List<int>>();
    _audioStreamSubscription = _recorder.audioStream.listen((data) {
      print(data);
      _audioStream.add(data);
    });

    //Configuration for the audio recording and speech contexts for dialogflow
    var biasList = SpeechContextV2Beta1(
        phrases: [
          'Dialogflow CX',
          'Dialogflow Essentials',
          'Action Builder',
          'HIPAA'
        ],
        boost: 20.0
    );

    // Change based on your machine 
    var config = InputConfigV2beta1(
        encoding: 'AUDIO_ENCODING_LINEAR_16',
        languageCode: 'en-US',
        sampleRateHertz: 16000,
        singleUtterance: false,
        speechContexts: [biasList],
    );

    //sending the stream to dialogflow
    final responseStream = dialogflow.streamingDetectIntent(config, _audioStream);

    //listening on the responseStream for results
    responseStream.listen((data) {
      setState(() {
        String transcript = data.recognitionResult.transcript;
        String queryText = data.queryResult.queryText;
        String fulfillmentText = data.queryResult.fulfillmentText;

        if(fulfillmentText.isNotEmpty) {
          ChatMessage message = ChatMessage(
              key: Key(queryText),
              text: queryText,
              name: "You",
              type: true,
          );

          ChatMessage botMessage = ChatMessage(
              key: Key(fulfillmentText),
              text: fulfillmentText,
              name: 'Bot',
              type: false,
          );

          _messages.insert(0, message);
          _textController.clear();
          _messages.insert(0, botMessage);
        }
        if(transcript.isNotEmpty) {
          _textController.text = transcript;
        }
      });
    });
  }

  //UI widget
  @override
  Widget build(BuildContext context) {
    return Column(
        children: <Widget>[
          Flexible(
              child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  reverse: true,
                  itemBuilder: (_, int index) => _messages[index],
                  itemCount: _messages.length,
              )
          ),
          const Divider(height: 1.0),
          Container(
              decoration: BoxDecoration(color: Theme.of(context).cardColor),
              child: IconTheme(
                  data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
                  child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                          children: <Widget>[
                            Flexible(
                                child: TextField(
                                    controller: _textController,
                                    onSubmitted: handleSubmitted,
                                    decoration: const InputDecoration.collapsed(hintText: "Ask Something"),
                                ),
                            ),
                            Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: IconButton(
                                    icon: const Icon(Icons.send),
                                    onPressed: () => handleSubmitted(_textController.text),
                                ),
                            ),
                            IconButton(
                                iconSize: 30.0,
                                icon: Icon(_isRecording ? Icons.mic_off: Icons.mic),
                                onPressed: _isRecording ? stopStream : handleStream,
                            ),
                          ],
                          ),
                          ),
                          ),
                          ),
                          ],
                          );
  }
}

//ChatMessage object for each chat message element
class ChatMessage extends StatelessWidget {
  const ChatMessage({required Key key, required this.text, required this.name, required this.type}): super(key: key);

  final String text;
  final String name;
  final bool type;

  List<Widget> otherMessage(context) {
    return <Widget> [
      Container(
          margin: const EdgeInsets.only(right: 16.0),
          child: CircleAvatar(child: Text(name[0]), backgroundColor: Theme.of(context).accentColor),
      ),
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Container(
                    margin: const EdgeInsets.only(top: 5.0),
                    child: Linkify(
                        onOpen: (link) async {
                          if(await canLaunch(link.url)) {
                            await launch(link.url);
                          } else {
                            throw "Could not launch ${link.url}";
                          }
                        },
                        text: text,
                    ),
                ),
              ],
          ),
      ),
      ];
  }

  List<Widget> myMessage(context) {
    return <Widget>[
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget> [
                Text(name, style:Theme.of(context).textTheme.subtitle1),
                Container(
                    margin: const EdgeInsets.only(top: 5.0),
                    child: Text(text),
                ),
              ],
          ),
      ),

      Container(
          margin: const EdgeInsets.only(left: 16.0),
          child: CircleAvatar (
              backgroundColor:Theme.of(context).accentColor,
              child: Text(
                  name[0],
                  style: const TextStyle(fontWeight:  FontWeight.bold),
              ),
          ),
      ),
      ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: type ? myMessage(context): otherMessage(context),
        ),
    );
  }
}
