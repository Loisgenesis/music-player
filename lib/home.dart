import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:music_player/my_colors.dart';
import 'package:music_player/my_strings.dart';
import 'package:music_player/single_page.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xml2json/xml2json.dart';
import 'package:url_launcher/url_launcher.dart';

const double _kFlexibleSpaceMaxHeight = 280.0;

class _BackgroundLayer {
  _BackgroundLayer({int level, double parallax})
      : parallaxTween = new Tween<double>(begin: 0.0, end: parallax);
  final Tween<double> parallaxTween;
}

final List<_BackgroundLayer> _kBackgroundLayers = <_BackgroundLayer>[
  new _BackgroundLayer(level: 0, parallax: _kFlexibleSpaceMaxHeight),
  new _BackgroundLayer(level: 1, parallax: _kFlexibleSpaceMaxHeight),
  new _BackgroundLayer(level: 2, parallax: _kFlexibleSpaceMaxHeight / 2.0),
  new _BackgroundLayer(level: 3, parallax: _kFlexibleSpaceMaxHeight / 4.0),
  new _BackgroundLayer(level: 4, parallax: _kFlexibleSpaceMaxHeight / 2.0),
  new _BackgroundLayer(level: 5, parallax: _kFlexibleSpaceMaxHeight)
];

class _AppBarBackground extends StatelessWidget {
  const _AppBarBackground({Key key, this.animation, this.imageUrl, this.text})
      : super(key: key);

  final Animation<double> animation;
  final String imageUrl;
  final String text;

  @override
  Widget build(BuildContext context) {
    Size query = MediaQuery.of(context).size;
    return new AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget child) {
          return new Stack(
              children: _kBackgroundLayers.map((_BackgroundLayer layer) {
            return new Positioned(
              top: -layer.parallaxTween.evaluate(animation),
              left: 0.0,
              right: 0.0,
              bottom: 0.0,
              child: new CachedNetworkImage(
                imageUrl: imageUrl,
                height: query.height / 2,
                fit: BoxFit.cover,
              ),
            );
          }).toList());
        });
  }
}

class Home extends StatefulWidget {
  @override
  HomeState createState() => new HomeState();
}

class HomeState extends State<Home> {
  final refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  var _isRequestSent = true;
  var _isRequestFailed = false;
  var _isRequestConnection = false;
  List<Data> data = [];
  String errorMessage;
  Xml2Json xml2json = new Xml2Json();
  String imageUrl;
  String title;
  String link;
  int count = 0;
  @override
  void initState() {
    getData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    count = 0;
    Size query = MediaQuery.of(context).size;
    return new Scaffold(
        backgroundColor: Colors.white,
        body: _isRequestSent
            ? _getProgressBar()
            : _isRequestFailed || _isRequestConnection
                ? retryButton()
                : data.isEmpty
                    ? showNoData()
                    : RefreshIndicator(
                        child: new CustomScrollView(
                          slivers: <Widget>[
                            new SliverAppBar(
                              backgroundColor: MyColors.colorPrimary,
                              pinned: true,
                              titleSpacing: 0.0,
                              expandedHeight: query.height / 2,
                              centerTitle: false,
                              flexibleSpace: new FlexibleSpaceBar(
                                title: new InkWell(
                                  onLongPress: _launchURL,
                                  child: new Text(
                                    title,
                                  ),
                                ),
                                background: new _AppBarBackground(
                                  animation: kAlwaysDismissedAnimation,
                                  imageUrl: imageUrl,
                                ),
                              ),
                            ),
                            new SliverList(
                                delegate: new SliverChildListDelegate(
                                    getCompleteUI())),
                          ],
                        ),
                        onRefresh: refreshList,
                      ));
  }

  Future<Null> refreshList() async {
    data.clear();
    getData();
    return null;
  }

  List<Widget> getCompleteUI() {
    List<Widget> widgets = [];
    for (var i = 0; i < data.length; i++) {
      count += 1;
      widgets.add(new Container(
        child: _getCardItems(i, count),
      ));
    }
    return widgets;
  }

  Widget _getCardItems(int position, int count) {
    Data datas = data[position];
    String newTitle = datas.title.replaceAll(r"\", r'');
    return new InkWell(
      onTap: (){
        singlePage(datas);
      },
      child: new Padding(
        padding: EdgeInsets.only(left: 20.0,right: 20.0,top: 5.0,bottom: 5.0),
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new Text(count.toString()),
            new SizedBox(
              width: 10.0,
            ),
            new Expanded(child: new Text(newTitle)),
            PopupMenuButton<String>(
              //onSelected: showMenuSelection,
              itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
                    const PopupMenuItem<String>(
                      value: 'Toolbar menu',
                      child: Text('Open'),
                    ),
//              const PopupMenuItem<String>(
//                value: 'Right here',
//                child: Text('Right here'),
//              ),
//              const PopupMenuItem<String>(
//                value: 'Hooray!',
//                child: Text('Hooray!'),
//              ),
                  ],
            ),
          ],
        ),
      ),
    );
  }
  void singlePage(Data data) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) => new SinglePage(data),
        ));
  }

  Widget placeHolder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300],
      highlightColor: Colors.grey[100],
      child: Container(
        height: 300.0,
        width: double.infinity,
        color: Colors.white,
      ),
    );
  }

  Widget showNoData() {
    return Container(
        alignment: Alignment.center,
        child: new Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            new Text(
              "No music player found",
              style: const TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            new SizedBox(
              height: 10.0,
            ),
            new FlatButton(
              onPressed: handleRetry,
              color: Colors.orange,
              textColor: Colors.white,
              child: const Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 15.0, horizontal: 20.0),
                child: const Text('RETRY'),
              ),
            ),
          ],
        ));
  }

  Widget _getProgressBar() {
    return new Center(
      child: new Container(
        width: 50.0,
        height: 50.0,
        child: new CircularProgressIndicator(),
      ),
    );
  }

  Widget retryButton() {
    return Container(
        alignment: Alignment.center,
        child: new Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            new Text(
              _isRequestConnection
                  ? Strings.networkError
                  : errorMessage == null || errorMessage.isEmpty
                      ? Strings.sthWentWrg
                      : errorMessage,
              style: const TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            new SizedBox(
              height: 10.0,
            ),
            new FlatButton(
              onPressed: handleRetry,
              color: Colors.orange,
              textColor: Colors.white,
              child: const Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 15.0, horizontal: 20.0),
                child: const Text('RETRY'),
              ),
            ),
          ],
        ));
  }

  _launchURL() async {
    var url = link;
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  //this method gets data from api
  void getData() async {
    count = 0;
    try {
      String url =
          'http://feeds.soundcloud.com/users/soundcloud:users:209573711/sounds.rss';
      http.Response response = await http.get(url);
      xml2json.parse(response.body);
      var jsonData = xml2json.toGData();
      Map<String, dynamic> body = json.decode(jsonData);
      imageUrl = body["rss"]["channel"]["image"]["url"]["\$t"];
      title = body["rss"]["channel"]["image"]["title"]["\$t"];
      link = body["rss"]["channel"]["image"]["link"]["\$t"];
      var dat = body["rss"]["channel"]['item'] as List;
      for (var i = 0; i < dat.length; i++) {
        var details = Data.getPostFrmJSONPost(dat[i]);
        data.add(details);

      }
      setState(() {
        _isRequestSent = false;
        _isRequestFailed = false;
      });
    } catch (e, stacktrace) {
      print(e);
      print(stacktrace);
      _handleRequestError(e);
    }
  }

  void _handleRequestError(e) {
    var message;
    if (message is TimeoutException) {
      message = Strings.requestTimeOutMsg;
    }
    if (!mounted) {
      return;
    }
    errorMessage = message ??= Strings.sthWentWrg;
    setState(() {
      _isRequestSent = false;
      _isRequestFailed = false;
      _isRequestConnection = e is SocketException;
    });
  }

  void handleRetry() {
    data.clear();
    setState(() {
      _isRequestSent = true;
      _isRequestFailed = false;
      _isRequestConnection = false;
    });
    getData();
  }
}

class Data {
  String id;
  String title;
  String pubDate;
  String link;
  String itunesDuration;
  String itunesAuthor;
  String itunesExplicit;
  String itunesSummary;
  String itunesSubtitle;
  String desc;
  String enclosureType;
  String enclosureUrl;
  String itunesImage;

  Data(
      this.id,
      this.title,
      this.pubDate,
      this.link,
      this.itunesDuration,
      this.itunesAuthor,
      this.itunesSummary,
      this.itunesExplicit,
      this.itunesSubtitle,
      this.desc,
      this.enclosureType,
      this.enclosureUrl,
      this.itunesImage);

  static Data getPostFrmJSONPost(dynamic jsonObject) {
    String id = jsonObject['guid']['\$t'];
    String title = jsonObject['title']['\$t'];
    String pubDate = jsonObject['pubDate']['\$t'];
    String link = jsonObject['link']['\$t'];
    String itunesDuration = jsonObject['itunes\$duration']['\$t'];
    String itunesAuthor = jsonObject['itunes\$author']['\$t'];
    String itunesExplicit = jsonObject['itunes\$explicit']['\$t'];
    String itunesSummary = jsonObject['itunes\$summary']['\$t'];
    String itunesSubtitle = jsonObject['itunes\$subtitle']['\$t'];
    String desc = jsonObject['description']['\$t'];
    String enclosureType = jsonObject['enclosure']['type'];
    String enclosureUrl = jsonObject['enclosure']['url'];
    String itunesImage = jsonObject['itunes\$image']['href'];
    return new Data(
        id,
        title,
        pubDate,
        link,
        itunesDuration,
        itunesAuthor,
        itunesSummary,
        itunesExplicit,
        itunesSubtitle,
        desc,
        enclosureType,
        enclosureUrl,
        itunesImage);
  }

  @override
  String toString() {
    return 'Data{id: $id, title: $title, pubDate: $pubDate, link: $link, itunesDuration: $itunesDuration, itunesAuthor: $itunesAuthor, itunesExplicit: $itunesExplicit, itunesSummary: $itunesSummary, itunesSubtitle: $itunesSubtitle, desc: $desc, enclosureType: $enclosureType, enclosureUrl: $enclosureUrl, itunesImage: $itunesImage}';
  }
}
