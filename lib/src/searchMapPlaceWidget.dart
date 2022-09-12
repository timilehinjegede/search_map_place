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
    this.width,
    this.inputDecoration,
  }) : assert((location == null && radius == null) ||
            (location != null && radius != null));

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

  // The input decoration to use for the TextField widget
  final InputDecoration? inputDecoration;

  @override
  SearchMapPlaceWidgetState createState() => SearchMapPlaceWidgetState();
}

class SearchMapPlaceWidgetState extends State<SearchMapPlaceWidget>
    with SingleTickerProviderStateMixin {
  TextEditingController? _textEditingController;
  late AnimationController _animationController;
  // SearchContainer height.

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
    _animationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 500));

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: widget.inputDecoration ?? _inputStyle(),
          controller: _textEditingController,
          style: this.widget.placeholderStyle,
          onChanged: (value) => setState(() {
            _autocompletePlace(value);
          }),
        ),
        SizedBox(height: 20),
        Expanded(
          child: Column(
            children: [
              if (_placePredictions!.length > 0)
                for (var prediction in _placePredictions!)
                  _placeOption(Place.fromJSON(prediction, geocode)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeOption(Place prediction) {
    String place = prediction.description!;

    return MaterialButton(
      padding: EdgeInsets.symmetric(vertical: 2),
      onPressed: () => _selectPlace(prediction),
      child: ListTile(
        minLeadingWidth: 10,
        leading: Icon(
          Icons.location_on_outlined,
          color: Colors.black,
        ),
        title: Text(
          place.length < 45
              ? "$place"
              : "${place.replaceRange(45, place.length, "")} ...",
          style: this.widget.resultsStyle,
          maxLines: 1,
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  // Styling
  InputDecoration _inputStyle() {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
      ),
      hintText: 'Location',
      prefixIcon: Icon(
        Icons.search,
        color: Colors.black,
        size: 28,
      ),
      suffixIcon: _textEditingController!.text.trim().isNotEmpty
          ? InkWell(
              onTap: () {
                setState(() {
                  _textEditingController!.clear();
                  _placePredictions = [];
                });
              },
              child: Icon(
                Icons.close_rounded,
                color: Colors.black,
                size: 28,
              ),
            )
          : SizedBox.shrink(),
    );
  }

  // Methods
  Future<void> _autocompletePlace(String input) async {
    /// Will be called everytime the input changes. Making callbacks to the Places
    /// Api and giving the user Place options

    if (input.length > 0) {
      mustBeClosed = false;
      String urlString =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=${widget.apiKey}&language=${widget.language}";
      if (widget.location != null && widget.radius != null) {
        urlString +=
            "&location=${widget.location!.latitude},${widget.location!.longitude}&radius=${widget.radius}";
        if (widget.strictBounds) {
          urlString += "&strictbounds";
        }
      }
      final response = await http.get(Uri.parse(urlString));
      final json = JSON.jsonDecode(response.body);

      if (json["error_message"] != null) {
        var error = json["error_message"];
        if (error == "This API project is not authorized to use this API.")
          error +=
              " Make sure the Places API is activated on your Google Cloud Platform";
        throw Exception(error);
      } else {
        if (!mustBeClosed) {
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
      selection:
          TextSelection.collapsed(offset: prediction.description!.length),
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
