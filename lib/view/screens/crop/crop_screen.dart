import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:openscan/view/Widgets/cropper/polygon_painter.dart';
import 'package:openscan/view/screens/crop/crop_screen_state.dart';
import 'package:vector_math/vector_math.dart' as vector;

Future<File> imageCropper(BuildContext context, File image) async {
  File? croppedImage;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CropImage(
        file: image,
      ),
    ),
  ).then((value) => croppedImage = value);
  return croppedImage ?? image;
}

class CropImage extends StatefulWidget {
  final File? file;

  CropImage({this.file});

  _CropImageState createState() => _CropImageState();
}

class _CropImageState extends State<CropImage> {
  CropScreenState _cropScreen = CropScreenState();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool cropLoading = false;

  @override
  initState() {
    super.initState();
    _cropScreen.imageFile = widget.file;
    _cropScreen.detectDocument();
    _cropScreen.canvasSize = Size(0, 0);
    _cropScreen.rotationAngle = 0; //-pi/2;
    _cropScreen.originalCanvasSize = Size(0, 0);
    _cropScreen.tl = Offset(0, 0);
    _cropScreen.tr = Offset(0, 0);
    _cropScreen.bl = Offset(0, 0);
    _cropScreen.br = Offset(0, 0);
    _cropScreen.t = Offset(0, 0);
    _cropScreen.l = Offset(0, 0);
    _cropScreen.b = Offset(0, 0);
    _cropScreen.r = Offset(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    _cropScreen.screenSize = MediaQuery.of(context).size;
    debugPrint(
        'Screen size=> ${_cropScreen.screenSize.width} / ${_cropScreen.screenSize.height}');
    return SafeArea(
      child: WillPopScope(
        onWillPop: () async {
          // Navigator.pop(context, null);
          return true;
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          key: _scaffoldKey,
          appBar: AppBar(
            title: Text(
              AppLocalizations.of(context)!.crop,
              // style: TextStyle().appBarStyle,
            ),
            centerTitle: true,
            elevation: 0.0,
            backgroundColor: Theme.of(context).primaryColor,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios),
              padding: EdgeInsets.fromLTRB(15, 8, 0, 8),
              onPressed: () {
                Navigator.pop(context, null);
              },
            ),
            actions: [
              MaterialButton(
                child: Icon(Icons.document_scanner_rounded),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onPressed: () {
                  setState(() {
                    _cropScreen.initPoints();
                    debugPrint('TL: ${_cropScreen.tl}');
                  });
                },
              )
            ],
          ),
          body: GestureDetector(
            key: _cropScreen.bodyKey,
            onPanUpdate: (updateDetails) {
              _cropScreen.updatedPoint.value = updateDetails;
              _cropScreen.updatePolygon();
            },
            onPanStart: (startDetails) {
              _cropScreen.calculateAllSlopes();
              _cropScreen.getMovingPoint(startDetails);
              if (_cropScreen.movingPoint.name != 'none')
                _cropScreen.showMagnifier.value = true;
            },
            onPanEnd: (details) {
              _cropScreen.movingPoint.name = 'none';
              _cropScreen.movingPoint.offset = Offset.zero;
              _cropScreen.showMagnifier.value = false;
            },
            child: Container(
              // width: _cropScreen.screenSize.width,
              // height: _cropScreen.screenSize.height,
              color: Theme.of(context).primaryColor,
              child: Stack(
                children: [
                  Container(
                    padding: EdgeInsets.all(13),
                    alignment: Alignment.center,
                    child: !cropLoading
                        ? TweenAnimationBuilder(
                            tween: Tween(
                                begin: 1.0,
                                end: _cropScreen.scaleImage
                                    ? _cropScreen.aspectRatio
                                    : 1.0),
                            duration: Duration(milliseconds: 100),
                            builder: ((_, double scale, __) {
                              return Transform.rotate(
                                angle: _cropScreen.rotationAngle,
                                child: Transform.scale(
                                  scale: scale,
                                  child: Image(
                                    key: _cropScreen.imageKey,
                                    image: FileImage(_cropScreen.imageFile!),
                                    loadingBuilder:
                                        ((context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      );
                                    }),
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Icon(
                                          Icons.error_rounded,
                                          color: Colors.red,
                                          size: 30,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }),
                          )
                        : CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation(
                              Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: _cropScreen.detectionCompleted,
                    builder: (context, _documentDetected, _) {
                      if (_cropScreen.detectionCompleted.value) {
                        /// This snippet is crucial, but idk how it works
                        _cropScreen.getRenderedBoxSize();
                        _cropScreen.initPoints();
                      }
                      return _cropScreen.detectionCompleted.value
                          ? _cropScreen.imageRendered.value
                              ? Positioned.fill(
                                  child: ValueListenableBuilder(
                                      valueListenable: _cropScreen.updatedPoint,
                                      builder: (context, _updatedPoint, _) {
                                        return CustomPaint(
                                          painter: PolygonPainter(
                                            tl: _cropScreen.tl,
                                            tr: _cropScreen.tr,
                                            bl: _cropScreen.bl,
                                            br: _cropScreen.br,
                                            t: _cropScreen.t,
                                            l: _cropScreen.l,
                                            b: _cropScreen.b,
                                            r: _cropScreen.r,
                                          ),
                                        );
                                      }),
                                )
                              : Container()
                          : Positioned.fill(
                              child: Container(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.7),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                ),
                              ),
                            );
                    },
                  ),
                  ValueListenableBuilder(
                    valueListenable: _cropScreen.showMagnifier,
                    builder: (context, bool _showMagnifier, _) {
                      if (_showMagnifier)
                        return ValueListenableBuilder(
                          valueListenable: _cropScreen.updatedPoint,
                          builder:
                              (context, DragUpdateDetails _updatedPoint, _) {
                            return Positioned(
                              left: _cropScreen.movingPoint.offset!.dx - 40,
                              top: _cropScreen.movingPoint.offset!.dy - 120,
                              child: RawMagnifier(
                                decoration: MagnifierDecoration(
                                  shadows: const <BoxShadow>[
                                    BoxShadow(
                                        blurRadius: 1.5,
                                        offset: Offset(0, 2),
                                        spreadRadius: 1,
                                        color: Color.fromARGB(25, 0, 0, 0))
                                  ],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: .15,
                                    ),
                                  ),
                                ),
                                size: Size(80, 80),
                                magnificationScale: 1.5,
                                focalPointOffset: Offset(0, 80),
                              ),
                            );
                          },
                        );
                      return Container();
                    },
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: bottomBar(),
        ),
      ),
    );
  }

  Widget bottomBar() {
    return Container(
      color: Theme.of(context).primaryColor,
      width: MediaQuery.of(context).size.width,
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          MaterialButton(
            elevation: 0,
            highlightElevation: 0,
            color: Colors.transparent,
            splashColor: Colors.transparent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rotate_left_rounded),
                Text(
                  'Rotate Left',
                  style: TextStyle(fontSize: 9),
                )
              ],
            ),
            onPressed: () async {
              setState(() {
                /// Subtracting 90* from image rotation
                _cropScreen.rotationAngle =
                    (_cropScreen.rotationAngle - pi / 2) % (2 * pi);
                debugPrint('rotationAngle => ${_cropScreen.rotationAngle}');

                /// Scaling image before rotation- solves Transform.rotate issue
                _cropScreen.scaleImage =
                    _cropScreen.rotationAngle % pi == pi / 2;
                debugPrint(_cropScreen.scaleImage.toString());

                /// Updates canvas size that is passed to PolygonBuilder
                _cropScreen.canvasSize = _cropScreen.scaleImage
                    ? Size(
                        _cropScreen.canvasSize.height * _cropScreen.aspectRatio,
                        _cropScreen.canvasSize.width * _cropScreen.aspectRatio)
                    : _cropScreen.imageBox.size;
                debugPrint(_cropScreen.canvasSize.toString());
                debugPrint('TL: ${_cropScreen.tl}');
              });
            },
          ),
          MaterialButton(
            elevation: 0,
            highlightElevation: 0,
            color: Colors.transparent,
            splashColor: Colors.transparent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rotate_right_rounded),
                Text(
                  'Rotate Right',
                  style: TextStyle(fontSize: 9),
                )
              ],
            ),
            onPressed: () async {
              setState(() {
                /// Adding 90* to image rotation
                _cropScreen.rotationAngle =
                    (_cropScreen.rotationAngle + pi / 2) % (2 * pi);
                debugPrint(
                    'rotationAngle => ${vector.degrees(_cropScreen.rotationAngle)}');

                /// Scaling image before rotation- solves Transform.rotate issue
                _cropScreen.scaleImage =
                    _cropScreen.rotationAngle % pi == pi / 2;
                debugPrint(_cropScreen.scaleImage.toString());

                /// Updates canvas size to be passed to PolygonBuilder
                _cropScreen.canvasSize = _cropScreen.scaleImage
                    ? Size(
                        _cropScreen.canvasSize.height * _cropScreen.aspectRatio,
                        _cropScreen.canvasSize.width * _cropScreen.aspectRatio)
                    : _cropScreen.imageBox.size;
                debugPrint(_cropScreen.canvasSize.toString());
              });
            },
          ),
          ValueListenableBuilder(
            valueListenable: _cropScreen.imageRendered,
            builder: (context, bool _imageRendered, _) {
              return MaterialButton(
                onPressed: _imageRendered
                    ? () {
                        Size canvasSize = _cropScreen.canvasSize;
                        Offset offset = _cropScreen.canvasOffset;
                        Offset tl = _cropScreen.tl-offset;
                        Offset tr = _cropScreen.tr-offset;
                        Offset br = _cropScreen.br-offset;
                        Offset bl = _cropScreen.bl-offset;
                        Size imageSize = _cropScreen.imageSize!;
                        // TODO:
                        // image rotation doesn't rotate
                        debugPrint('Rotation Angle: '+(_cropScreen.rotationAngle*180/pi).toString());
                        debugPrint('Crop Percent: '+ (tl.dx/canvasSize.width).toString()+','+(tl.dy/canvasSize.height).toString()+' - '+(tr.dx/canvasSize.width).toString()+','+(tr.dy/canvasSize.height).toString()+' - '+(br.dx/canvasSize.width).toString()+','+(br.dy/canvasSize.height).toString()+' - '+ (bl.dx/canvasSize.width).toString()+','+(bl.dy/canvasSize.height).toString());
                        if (imageSize.height > imageSize.width) {
                          _cropScreen.tr = Offset(canvasSize.width*tr.dy/canvasSize.height,canvasSize.height*(1-tr.dx/canvasSize.width));
                          _cropScreen.br = Offset(canvasSize.width*br.dy/canvasSize.height,canvasSize.height*(1-br.dx/canvasSize.width));
                          _cropScreen.bl = Offset(canvasSize.width*bl.dy/canvasSize.height,canvasSize.height*(1-bl.dx/canvasSize.width));
                          _cropScreen.tl = Offset(canvasSize.width*tl.dy/canvasSize.height,canvasSize.height*(1-tl.dx/canvasSize.width));
                          //if (_cropScreen.rotationAngle % pi == 0)
                          _cropScreen.imageSize =
                            Size(imageSize.height, imageSize.width);
                        }
                        else {
                          _cropScreen.tl = Offset(tl.dx, tl.dy);
                          _cropScreen.tr = Offset(tr.dx, tr.dy);
                          _cropScreen.br = Offset(br.dx, br.dy);
                          _cropScreen.bl = Offset(bl.dx, bl.dy);
                        }
                        setState(() {
                          cropLoading = true;
                        });
                        _cropScreen.crop();
                        setState(() {
                          cropLoading = false;
                        });
                        Navigator.pop(context, _cropScreen.imageFile);
                      }
                    : () {},
                color: _imageRendered || !cropLoading
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                splashColor: Colors.transparent,
                disabledColor:
                    Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                disabledTextColor: Colors.white.withOpacity(0.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.next,
                      style: TextStyle(
                        color: _imageRendered || !cropLoading
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                        fontSize: 18,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: _imageRendered || !cropLoading
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    )
                  ],
                ),
              );
            },
          )
        ],
      ),
    );
  }
}