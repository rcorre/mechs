
module entities;

import std.math;
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
    static immutable player     = spriteRect(0, 3 * 32, 32, 32);
    static immutable projectile = spriteRect(0, 4 * 32, 16, 16);
}

auto spriteRect(int x, int y, int w, int h) { return box2i(x, y, x + w, y + h); }

public:
auto createPlayer(EntityManager em) {
    auto ent = em.create();

    ent.register!Transform(vec2f(400, 400));
    ent.register!Velocity();
    ent.register!Sprite(SpriteRect.player);

    auto loadout = ent.register!Loadout;
    loadout.weapons[0] = Weapon(0.05, 0.25);
    loadout.weapons[1] = Weapon(0.3, 0.1);
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

void createProjectile(EntityManager em, vec2f pos, float angle, float speed) {
    auto ent = em.create();

    ent.register!Transform(pos, vec2f(1, 1), angle);
    ent.register!Velocity(vec2f(speed * cos(angle), speed * sin(angle)));
    ent.register!Sprite(SpriteRect.projectile, al_map_rgba(255,255,255,255));
    ent.register!RenderTrail(0.01); // create a 'ghost' every 0.01s
    ent.register!DestroyAfter(3.0); // ensure it doesn't hang around forever
}
