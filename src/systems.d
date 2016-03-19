module systems;

import std.math;
import std.range;
import std.algorithm;

import gfm.math;
import entitysysd;
import allegro5.allegro;
import allegro5.allegro_color;
import allegro5.allegro_primitives;

import common;
import events;
import entities;
import components;

class RenderSystem : System {
    private ALLEGRO_BITMAP* _spritesheet;
    private Entity _camera;

    this(ALLEGRO_BITMAP* spritesheet, Entity camera) {
        _spritesheet = spritesheet;
        _camera = camera;
    }

    override void run(EntityManager em, EventManager events, Duration dt) {
        assert(_camera.valid && _camera.isRegistered!Transform);

        // store old transformation to restore later.
        ALLEGRO_TRANSFORM oldTrans;
        al_copy_transform(&oldTrans, al_get_current_transform());

        // holding optimizes multiple draws from the same spritesheet
        al_hold_bitmap_drawing(true);

        ALLEGRO_TRANSFORM trans, baseTrans;

        auto cameraPos = _camera.component!Transform.pos;

        // set up the camera offset
        al_identity_transform(&baseTrans);
        al_translate_transform(&baseTrans,
                               -cameraPos.x + screenW / 2,
                               -cameraPos.y + screenH / 2);

        foreach (entity; em.entitiesWith!(Sprite, Transform)) {
            auto entityTrans = entity.component!Transform.allegroTransform;
            auto r = entity.component!Sprite.rect;

            // reset the current drawing transform
            al_identity_transform(&trans);

            // place the origin of the sprite at its center
            al_translate_transform(&trans, -r.width / 2, -r.height / 2);

            // apply the transform of the current entity
            al_compose_transform(&trans, &entityTrans);

            // finally, translate everything by the camera
            al_compose_transform(&trans, &baseTrans);

            al_use_transform(&trans);

            al_draw_tinted_bitmap_region(_spritesheet,
                                         entity.component!Sprite.tint,
                                         r.min.x, r.min.y, r.width, r.height,
                                         0, 0,
                                         0);
        }

        al_hold_bitmap_drawing(false);

        // restore previous transform
        al_use_transform(&oldTrans);
    }
}

class MotionSystem : System {
    override void run(EntityManager em, EventManager events, Duration dt) {
        immutable time = dt.total!"msecs" / 1000f; // in seconds

        foreach (ent, trans, vel; em.entitiesWith!(Transform, Velocity)) {
            trans.pos += vel.linear * time;
            trans.angle += vel.angular * time;
        }
    }
}

class UnitCollisionSystem : System {
}

class InputSystem : System, Receiver!AllegroEvent {
    private Entity _player;
    enum playerSpeed = 120;

    this(Entity player) {
        _player = player;
    }

    override void run(EntityManager es, EventManager events, Duration dt) {
    }

    void receive(AllegroEvent ev) {
        assert(_player.valid);

        auto pos(ALLEGRO_EVENT ev) { return vec2f(ev.mouse.x, ev.mouse.y); }

        auto trans = _player.component!Transform;
        auto vel = _player.component!Velocity;

        switch (ev.type) {
            case ALLEGRO_EVENT_KEY_DOWN:
                switch (ev.keyboard.keycode) {
                    case ALLEGRO_KEY_W:
                        vel.linear.y = -playerSpeed;
                        break;
                    case ALLEGRO_KEY_S:
                        vel.linear.y = playerSpeed;
                        break;
                    case ALLEGRO_KEY_A:
                        vel.linear.x = -playerSpeed;
                        break;
                    case ALLEGRO_KEY_D:
                        vel.linear.x = playerSpeed;
                        break;
                    default:
                }
                break;
            case ALLEGRO_EVENT_KEY_UP:
                switch (ev.keyboard.keycode) {
                    case ALLEGRO_KEY_W:
                    case ALLEGRO_KEY_S:
                        vel.linear.y = 0;
                        break;
                    case ALLEGRO_KEY_A:
                    case ALLEGRO_KEY_D:
                        vel.linear.x = 0;
                        break;
                    default:
                }
                break;
            case ALLEGRO_EVENT_MOUSE_AXES:
                auto disp = pos(ev) - vec2f(screenW, screenH) / 2;
                trans.angle = atan2(disp.y, disp.x);
                break;
            case ALLEGRO_EVENT_MOUSE_BUTTON_DOWN:
                if (ev.mouse.button == 1) // fire primary
                    _player.component!Loadout.weapons[0].firing = true;
                else if (ev.mouse.button == 2) // fire secondary
                    _player.component!Loadout.weapons[1].firing = true;
                break;
            case ALLEGRO_EVENT_MOUSE_BUTTON_UP:
                if (ev.mouse.button == 1) // stop firing primary
                    _player.component!Loadout.weapons[0].firing = false;
                else if (ev.mouse.button == 2) // stop firing secondary
                    _player.component!Loadout.weapons[1].firing = false;
                break;
            default:
        }
    }
}

class AnimationSystem : System {
    private enum maxFrame = 8;  // all animations have 8 frames

    override void run(EntityManager em, EventManager events, Duration dt) {
        foreach (ent, ani, sprite; em.entitiesWith!(Animator, Sprite)) {
            immutable elapsed = dt.total!"msecs" / 1000f;

            if (ani.run && (ani.countdown -= elapsed) < 0) {
                ani.countdown = ani.duration;
                ani.frame = (ani.frame + 1) % maxFrame;
            }

            sprite.rect = ani.start.translate(ani.offset * ani.frame);
        }
    }
}

class WeaponSystem : System {
    override void run(EntityManager em, EventManager events, Duration dt) {
        enum projectileSpeed = 600;

        foreach (ent, trans, loadout; em.entitiesWith!(Transform, Loadout)) {
            immutable elapsed = dt.total!"msecs" / 1000f;

            foreach(ref w ; loadout.weapons) {
                if ((w.countdown -= elapsed) < 0 && w.firing) {
                    w.countdown = w.fireDelay;
                    em.createProjectile(trans.pos, trans.angle, projectileSpeed);
                }
            }
        }
    }
}
