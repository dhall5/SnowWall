
// import libraries
import processing.opengl.*; 
import SimpleOpenNI.*; 
import blobDetection.*; 
import toxi.geom.*; 
import toxi.processing.*; 
import shiffman.box2d.*; 
import org.jbox2d.collision.shapes.*; 
//import org.jbox2d.dynamics.joints.*;
import org.jbox2d.common.*; 
import org.jbox2d.dynamics.*; 
import java.util.Collections;
import java.util.Comparator; 

SimpleOpenNI context;
BlobDetection theBlobDetection;
ToxiclibsSupport gfx;
ArrayList<PolygonBlob> polys = new ArrayList<PolygonBlob>();
PolygonBlob poly;

PImage blobs;
int kinectWidth = 640;
int kinectHeight = 480;

float reScale;
String[] palettes = {
  "A32C28,1C090B,384030,7B8055,BCA875,384030,7B8055,BCA875",
  "E8C382,B39D69,A86B4C,7D1A0C,340A0B,A86B4C,7D1A0C,340A0B",
  "941F1F,CE6B5D,FFEFB9,7B9971,34502B,FFEFB9,7B9971,34502B",
  "9E3333,AB6060,D4D1A5,7BBD82,3D9949,D4D1A5,7BBD82,3D9949",
  "E3EDE8,587A55,CF0F1B,1E340E,F2F4F2,CF0F1B,1E340E,F2F4F2",
  "DBD9B7,C1C9C8,A5B5AB,949A8E,615566,A5B5AB,949A8E,615566",
  "36282A,5C323F,6D9381,B7C2A2,E9F6FC,6D9381,B7C2A2,E9F6FC"
};
IntList  colorPalette = new IntList(8);
int[] userMapping;
int[] userID;


Box2DProcessing box2d;
ArrayList<CustomShape> polygons = new ArrayList<CustomShape>();

PShape[] shapes = new PShape[4];
PImage[] bgs = new PImage[9];
String bgFolder ="";

PImage bg;

boolean sketchFullScreen() {
  return true;
}

void setup() {
  println("SET UP");
  size(displayWidth, displayHeight);

  frameRate(30);
  context = new SimpleOpenNI(this);

  if (!context.enableDepth() || !context.enableUser()) {
    println("Kinect not connected!"); 
    exit();
  } else {
    for (int i = 0; i < shapes.length; i ++) {
      shapes[i] = loadShape( i +".svg");
     }

    bgFolder = "bg" + displayWidth + "x" + displayHeight;
    for(int i = 0; i < bgs.length; i ++ ) {
      bgs[i] = loadImage( bgFolder + "/bg" + i +  ".jpg" ); 
    }

    context.setMirror(false);
    //context.alternativeViewPointDepthToImage();
    reScale = (float) width / kinectWidth;
    // create a smaller blob image for speed and efficiency
    //blobs = createImage(kinectWidth/4, kinectHeight/4, ALPHA);
    blobs = createImage(kinectWidth/3, kinectHeight/3, RGB );
    theBlobDetection = new BlobDetection(blobs.width, blobs.height);
    theBlobDetection.setThreshold(0.3);
    gfx = new ToxiclibsSupport(this);
    box2d = new Box2DProcessing(this);
    box2d.createWorld();
    box2d.setGravity(0, -8);
    setRandomColors(1);
  }
}


void draw() {
  background(bg);

  PVector pos = new PVector();//this will store the position of the user
  userID = context.getUsers();
  for (int i=0; i<userID.length; i++)
  {
    context.getCoM(userID[i],pos);
    if (pos.z>0) {
      poly = new PolygonBlob();
      poly.user=createImage(kinectWidth, kinectHeight, ALPHA);
      poly.userID=userID[i];
      poly.userDistance=pos.z;
      //poly.col= colorPalette.get(userID[i]-1);   //getRandomColor();
      poly.col= getRandomColor();
      polys.add(poly);
    }
  }
  context.update();
  loadPixels();


  // for the length of the pixels tracked, color them
  // in with the rgb camera
  // get pixels for the user tracked
  userMapping = context.userMap();

  for (int i =0; i < userMapping.length; i++) {
    // if the pixel is part of the user
    if (userMapping[i] != 0) {
      for (int j=0; j<polys.size (); j++) {
        poly = polys.get(j);
        if (poly.userID==userMapping[i]) {
          poly.user.pixels[i]=color(255, 255, 255);
          break;
        }
      }
    } // if (userMap[i] != 0)
  } // (int i =0; i < userMap.length; i++)
  // update any changed pixels
  updatePixels();

  Collections.sort(polys, new Comparator<PolygonBlob>() {
        @Override public int compare(PolygonBlob p1, PolygonBlob p2) {
            return int(p1.userDistance - p2.userDistance); // Ascending
        }

    });
  for (int j=0; j<polys.size (); j++) {
    poly = polys.get(j);
    blobs.copy(poly.user, 0, 0, poly.user.width, poly.user.height, 0, 0, blobs.width, blobs.height);
    blobs.filter(BLUR, 1);
    theBlobDetection.computeBlobs(blobs.pixels);
    poly.createPolygon();
    poly.createBody();
  }
  updateAndDrawBox2D();
  setRandomColors(384);
}

void updateAndDrawBox2D() {
  //PolygonBlob poly;
  if (frameRate>5) {
    polygons.add(new CustomShape(int(random(0, kinectWidth)), -50, int(random(9, 15)), BodyType.DYNAMIC,getRandomFlake()));
  }
  
  float timeStep = 1.0f / 30.0f;
  int velocityIterations = 5;
  int positionIterations = 4;
  //box2d.step();
  box2d.step(timeStep,velocityIterations, positionIterations);
  translate(0, (height-kinectHeight*reScale)/2);
  scale(reScale);


  for (int i=polygons.size ()-1; i>=0; i--) {
    CustomShape cs = polygons.get(i);
    if (cs.done()) {
      polygons.remove(i);
    } else {
      cs.update();
      cs.display();
    }
  }

  for (int j=0; j<polys.size (); j++) {
    poly=polys.get(j);
    noStroke();
    fill(poly.col);
    gfx.polygon2D(poly);
    poly.destroyBody();
  }
  polys.clear();
}





// sets the colors every nth frame
void setRandomColors(int nthFrame) {
  if (frameCount % nthFrame == 0) {
    // turn a palette into a series of strings
    String[] paletteStrings = split(palettes[int(random(palettes.length))], ",");
    colorPalette.clear();
    // turn strings into colors
   // colorPalette = new color[paletteStrings.length];
    for (int i=0; i<paletteStrings.length; i++) {
      //colorPalette[i] = int(paletteStrings[i]);
     // colorPalette[i] = unhex("FF"+paletteStrings[i]);
     colorPalette.add(i,unhex("FF"+paletteStrings[i]));
    }
    colorPalette.shuffle(this);
    bg=bgs[int(random(bgs.length))];
  }
}


// returns a random color from the palette (excluding first aka background color)
color getRandomColor() {
  return colorPalette.get(int(random(colorPalette.size())));
}


PShape getRandomFlake() {
  return shapes[int(random(shapes.length))];
}

// -----------------------------------------------------------------
// SimpleOpenNI events

void onNewUser(SimpleOpenNI curContext, int userId)
{
  println("onNewUser - userId: " + userId);
  println("\tstart tracking skeleton");
 
}

void onLostUser(SimpleOpenNI curContext, int userId)
{
 
  println("onLostUser - userId: " + userId);
}

void onVisibleUser(SimpleOpenNI curContext, int userId)
{
  //println("onVisibleUser - userId: " + userId);
}

