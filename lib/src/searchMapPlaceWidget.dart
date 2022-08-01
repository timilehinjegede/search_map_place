part of search_map_place;

class SearchMapPlaceWidget extends StatefulWidget {
  SearchMapPlaceWidget({
    this.key,
    required this.apiKey,
    this.placeholder = 'Search',
    this.placeholderStyle,
    this.resultsStyle,
    this.icon = Icons.search,
    this.iconColor = Colors.blue,
    this.onSelected,
    this.onSearch,
    this.language = 'en',
    this.location,
    this.radius,
    this.strictBounds = false,
    this.textEditingController,
    this.width
  }) : assert((location == null && radius == null) || (location != null && radius != null));

  GlobalKey<SearchMapPlaceWidgetState>? key;

  /// Used to allow clearing from outside the widget.
  TextEditingController? textEditingController = TextEditingController();

  /// API Key of the Google Maps API.
  final String apiKey;

  /// Placeholder text to show when the user has not entered any input.
  final String placeholder;

  /// Style for the placeholder text to show when the user has not entered any input.
  final TextStyle? placeholderStyle;

  /// Style for the results text.
  final TextStyle? resultsStyle;

  /// The callback that is called when one Place is selected by the user.
  final void Function(Place place)? onSelected;

  /// The callback that is called when the user taps on the search icon.
  final void Function(Place place)? onSearch;

  /// Language used for the autocompletion.
  ///
  /// Check the full list of [supported languages](https://developers.google.com/maps/faq#languagesupport) for the Google Maps API
  final String language;

  /// The point around which you wish to retrieve place information.
  ///
  /// If this value is provided, `radius` must be provided aswell.
  final LatLng? location;

  /// The distance (in meters) within which to return place results. Note that setting a radius biases results to the indicated area, but may not fully restrict results to the specified area.
  ///
  /// If this value is provided, `location` must be provided aswell.
  ///
  /// See [Location Biasing and Location Restrict](https://developers.google.com/places/web-service/autocomplete#location_biasing) in the documentation.
  final int? radius;

  /// Returns only those places that are strictly within the region defined by location and radius. This is a restriction, rather than a bias, meaning that results outside this region will not be returned even if they match the user input.
  final bool strictBounds;

  /// The icon to show in the search box
  final IconData icon;

  /// The color of the icon to show in the search box
  final Color iconColor;

  /// The width of the searchbar
  final double? width;

  @override
  SearchMapPlaceWidgetState createState() => SearchMapPlaceWidgetState();
}

class SearchMapPlaceWidgetState extends State<SearchMapPlaceWidget> with SingleTickerProviderStateMixin {
  TextEditingController? _textEditingController;
  late AnimationController _animationController;
  // SearchContainer height.
  late Animation _containerHeight;
  // Place options opacity.
  late Animation _listOpacity;

  List<dynamic>? _placePredictions = [];
  Place? _selectedPlace;
  Geocoding? geocode;
  bool mustBeClosed = true;

  @override
  void initState() {
    _textEditingController = widget.textEditingController;
    _selectedPlace = null;
    _placePredictions = [];
    geocode = Geocoding(apiKey: widget.apiKey, language: widget.language);
    _animationController = AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    _containerHeight = Tween<double>(begin: 55, end: 360).animate(
      CurvedAnimation(
        curve: Interval(0.0, 0.5, curve: Curves.easeInOut),
        parent: _animationController,
      ),
    );
    _listOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        curve: Interval(0.5, 1.0, curve: Curves.easeInOut),
        parent: _animationController,
      ),
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: widget.width != null ? widget.width : MediaQuery.of(context).size.width * 0.9,
        child: _searchContainer(
          child: _searchInput(context),
        ),
      );

  // Widgets
  Widget _searchContainer({Widget? child}) {
    return AnimatedBuilder(
        animation: _animationController,
        builder: (context, _) {
          return Container(
            height: _containerHeight.value,
            decoration: _containerDecoration(),
            padding: EdgeInsets.only(left: 0, right: 0, top: 4, bottom: 0),
            alignment: Alignment.center,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: child,
                ),
//                SizedBox(height: 5),
                Opacity(
                  opacity: _listOpacity.value,
                  child: Column(
                    children: <Widget>[
                      if (_placePredictions!.length > 0)
                        for (var prediction in _placePredictions!)
                          _placeOption(Place.fromJSON(prediction, geocode)),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
  }

  Widget _searchInput(BuildContext context) {
    return Center(
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              decoration: _inputStyle(),
              controller: _textEditingController,
//              style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.04),
            style: this.widget.placeholderStyle,
              onChanged: (value) => setState(() => _autocompletePlace(value)),
            ),
          ),
          Container(width: 15),
          GestureDetector(
            child: Icon(this.widget.icon, color: this.widget.iconColor),
            onTap: () => widget.onSearch!(Place.fromJSON(_selectedPlace, geocode)),
          )
        ],
      ),
    );
  }

  Widget _placeOption(Place prediction) {
    String place = prediction.description!;

    return MaterialButton(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      onPressed: () => _selectPlace(prediction),
      child: ListTile(
        title: Text(
          place.length < 45 ? "$place" : "${place.replaceRange(45, place.length, "")} ...",
          style: this.widget.resultsStyle,
          maxLines: 1,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 0,
        ),
      ),
    );
  }

  // Styling
  InputDecoration _inputStyle() {
    return InputDecoration(
      hintText: this.widget.placeholder,
      hintStyle: this.widget.placeholderStyle,
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
    );
  }

  BoxDecoration _containerDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.all(Radius.circular(6.0)),
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 10)],
    );
  }

  // Methods
  void _autocompletePlace(String input) async {
    /// Will be called everytime the input changes. Making callbacks to the Places
    /// Api and giving the user Place options

    if (input.length > 0) {
      mustBeClosed = false;
      String urlString =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=${widget.apiKey}&language=${widget.language}";
      if (widget.location != null && widget.radius != null) {
        urlString += "&location=${widget.location!.latitude},${widget.location!.longitude}&radius=${widget.radius}";
        if (widget.strictBounds) {
          urlString += "&strictbounds";
        }
      }
      final response = await http.get(Uri.parse(urlString));
      final json = JSON.jsonDecode(response.body);

      if (json["error_message"] != null) {
        var error = json["error_message"];
        if (error == "This API project is not authorized to use this API.")
          error += " Make sure the Places API is activated on your Google Cloud Platform";
        throw Exception(error);
      } else {
        if(!mustBeClosed){
          final predictions = json["predictions"];
          await _animationController.animateTo(0.5);
          setState(() => _placePredictions = predictions);
          await _animationController.forward();
        }
      }
    } else {
      reset();
    }
  }

  void reset() async {
    mustBeClosed = true;
//    await _animationController.animateTo(0.5);
    setState(() => _placePredictions = []);
    await _animationController.reverse();
  }

  void _selectPlace(Place prediction) async {
    /// Will be called when a user selects one of the Place options.

    // Sets TextField value to be the location selected
    _textEditingController!.value = TextEditingValue(
      text: prediction.description!,
      selection: TextSelection.collapsed(offset: prediction.description!.length),
    );

    // Makes animation
    await _animationController.animateTo(0.5);
    setState(() {
      _placePredictions = [];
      _selectedPlace = prediction;
    });
    _animationController.reverse();

    // Calls the `onSelected` callback
    widget.onSelected!(prediction);
  }
}
