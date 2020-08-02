import 'dart:async';

import 'package:flutter/material.dart';
//import 'package:flutter/foundation.dart' as Foundation;

import 'package:scoped_model/scoped_model.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:MyNews/models/news.dart';
import 'package:MyNews/scoped-models/main.dart';
import 'package:MyNews/services/custom_services.dart';

import 'package:MyNews/widgets/ui_elements/global_widgets/loading_shader_mask.dart';
import 'package:MyNews/widgets/ui_elements/news_widgets/news_card.dart';
//import 'package:MyNews/widgets/ui_elements/global_widgets/BannerAd.dart';

class NewsPage extends StatefulWidget {
  // Class Attributes

  final MainModel model;
  final int index;
  final bool saveSearch;
  final bool headlines;
  final String search;

  // NewsPage Constructor
  NewsPage(
      {this.model,
      this.index,
      this.saveSearch = false,
      this.headlines = false,
      this.search});

  @override
  _NewsPageState createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  // future value
  Future<Map<String, dynamic>> _future;
  //ScrollController _scrollController;
  // Called when this object is inserted into the tree.
  @override
  void initState() {
    // init future
    if (widget.saveSearch) {
      _future = fetchNews(forceFetch: true);
    }
    // _scrollController = ScrollController(keepScrollOffset: true);
    super.initState();
  }

  // loading widget
  Widget _buildLoadingWidget() {
    Widget loadingShadeMask = Padding(
      padding: EdgeInsets.symmetric(vertical: 6.0),
      child: LoadingShaderMask(
        targetWidth: MediaQuery.of(context).size.width * 0.9,
        targetHeight: MediaQuery.of(context).size.height * 0.4,
      ),
    );
    return ListView(
        padding: const EdgeInsets.all(8.0),
        physics: ScrollPhysics(),
        children: <Widget>[
          loadingShadeMask,
          loadingShadeMask,
          loadingShadeMask,
          loadingShadeMask,
          loadingShadeMask
        ]);
  }

  // // build Error widget method
  Widget _buildErrorWidget(String error) {
    String displayErrorText = error;
    if (error == 'Can\'t find articles') {
      displayErrorText += '\n\nOnly English search is valid.';
    }
    return Container(
      alignment: Alignment.topCenter,
      padding: EdgeInsets.all(15.0),
      child: Text(
        displayErrorText,
        style: Theme.of(context).textTheme.headline6,
      ),
    );
  }

  // hangle error method
  Widget _handleError(AsyncSnapshot<Map<String, dynamic>> snapshot) {
    // error cases

    // On There is no internet connection error
    if (snapshot.data['message'] == 'There is no internet connection') {
      //  show no connection Toast
      Fluttertoast.showToast(
        msg: 'There is no internet connection',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );

      // call repeate check connectivity to fetch when device has connection
      repeateCheckConnectivity();
      // return loading widget
      return _buildLoadingWidget();
    }

    return _buildErrorWidget(snapshot.data['message']);
  }

  // NewsCard List view builder
  Widget _buildNewsCardListView() {
    return ScopedModelDescendant<MainModel>(builder: (context, child, model) {
      List<News> newsList;

      // adjust newsList reference if saveSearch mode or not
      if (widget.saveSearch) {
        newsList = widget.model.getSearchNews;
      } else if (widget.headlines) {
        newsList = model.homePageListNews[widget.index];
      } else {
        try {
          newsList = model.getNewsList[widget.index];
        } on RangeError {
          return Container();
        }
      }

      if (newsList.isEmpty) {
        return _buildLoadingWidget();
      } else {
        return RefreshIndicator(
            child: ListView.builder(
              addAutomaticKeepAlives: true,
              physics: ScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 5.0),
              itemBuilder: (context, index) {
                return NewsCard(newsList[index], widget.model, index);
              },
              itemCount: newsList.length,
            ),
            onRefresh: _onRefresh);
      }
    });
  }

  // fetch news method
  Future<Map<String, dynamic>> fetchNews({forceFetch = false}) {
    // on SearchPage
    if (widget.saveSearch) {
      return widget.model.fetchNews(
          search: widget.search,
          saveSearchNews: widget.saveSearch,
          forceFetch: forceFetch);
      // on home page
    } else if (widget.headlines) {
      return widget.model.fetchNews(
          index: widget.index, forceFetch: forceFetch, headlines: true);
    } else {
      return widget.model.fetchNews(
          search: widget.model.getfollowingTopicsList[widget.index],
          index: widget.index,
          forceFetch: forceFetch);
    }
  }

  // checks every second connectivity
  void repeateCheckConnectivity() async {
    Timer.periodic(Duration(seconds: 1), (timer) async {
      bool connectivity = await Connectivity.internetConnectivity();
      // if connectivity is true call fetchNews and cancel timer
      if (connectivity) {
        fetchNews(forceFetch: true);
        timer.cancel();
      }
    });
  }

  // handle page return, call when the page has been initilise before and re-build again on runtime
  void handlePageReturn() async {
    bool connectivity = await Connectivity.internetConnectivity();
    if (!connectivity) {
      //Fluttertoast.cancel();
      //  show no connection Toast
      Fluttertoast.showToast(
        msg: 'There is no internet connection',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  // onRefresh indicatpr callback
  Future<void> _onRefresh() async {
    Map<String, dynamic> info = await fetchNews(forceFetch: true);
    if (info['message'] == 'There is no internet connection') {
      //  show no connection Toast
      Fluttertoast.showToast(
        msg: 'There is no internet connection',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    }
    return Future.value(true);
  }

  @override
  Widget build(BuildContext context) {
    // prevent re-build futureBuilder again when already fetched
    List<News> newsList;
    // adjust newsList
    if (widget.saveSearch) {
      newsList = widget.model.getSearchNews;
    } else if (widget.headlines) {
      newsList = widget.model.homePageListNews[widget.index];
    } else {
      newsList = widget.model.getNewsList[widget.index];
    }
    if (newsList.isNotEmpty) {
      handlePageReturn();
      return _buildNewsCardListView();
    } else
      return FutureBuilder<Map<String, dynamic>>(
        future: widget.saveSearch ? _future : fetchNews(forceFetch: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // future complete
            // if error or data is false return error widget
            if (snapshot.hasError) {
              return _buildErrorWidget('SOMETHING WENT WRONG, TAP TO RELOAD');
            }
            if (snapshot.data['error']) {
              return _handleError(snapshot);
            }
            // return news card listview
            return _buildNewsCardListView();

            // return loading widget while connection state is active
          } else {
            return _buildLoadingWidget();
          }
        },
      );
  }
}

// separatorBuilder: (context, index) {
//   return Container();
//   // dont show native ads in debug mode or index is not multiple of 7
//   // if (Foundation.kDebugMode || index % 7 != 0) return Container();

//   // return BannerAdWidget();
// },