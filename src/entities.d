
module entities;

import std.range;
import std.algorithm;

import dtiled;
import gfm.math;
import entitysysd;
import allegro5.allegro;
import allegro5.allegro_color;

import common;
import components;

private:
enum spriteSize = 32; // size of grid in spritesheet
enum animationOffset = vec2i(32, 0); // space between animation frames

struct SpriteRect {
    static immutable player = spriteAt(3, 0);
    static immutable speedPickup = spriteAt(4, 0);
    static immutable shieldPickup = spriteAt(4, 1);
}

auto spriteAt(int row, int col) {
    return box2i(col       * spriteSize,
                 row       * spriteSize,
                 (col + 1) * spriteSize,
                 (row + 1) * spriteSize);
}

public:
auto createPlayer(EntityManager em) {
    auto ent = em.create();

    ent.register!Transform(vec2f(400, 400));
    ent.register!Velocity();
    ent.register!Acceleration();
    ent.register!Sprite(SpriteRect.player);
    //ent.register!Animator(0.1f, SpriteRect.player, animationOffset);
    //ent.register!PlayerCollider(12); // radius = 12

    return ent;
}

void createMap(EntityManager em, string path) {
  auto mapData = MapData.load(path);
  auto tileset = mapData.tilesets[0];
  immutable tw = tileset.tileWidth;
  immutable th = tileset.tileHeight;

  // create wall tiles
  foreach(idx, gid ; mapData.getLayer("walls").data) {
      if (!gid) continue; // ignore spaces with no tile

      auto pos = vec2f((idx % mapData.numCols) * tw + tw / 2,
                       (idx / mapData.numCols) * th + th / 2);

      auto region = box2i(tileset.tileOffsetX(gid),
                          tileset.tileOffsetY(gid),
                          tileset.tileOffsetX(gid) + tileset.tileWidth,
                          tileset.tileOffsetY(gid) + tileset.tileHeight);

      auto ent = em.create();
      ent.register!Transform(pos);
      ent.register!Sprite(region);
  }

  // create colliders
  //foreach(obj ; mapData.getLayer("collision").objects) {
  //    auto box = box2f(obj.x,
  //                     obj.y,
  //                     obj.x + obj.width,
  //                     obj.y + obj.height);

  //    auto ent = em.create();
  //    ent.register!Collider(box, reflective);
  //}
}
