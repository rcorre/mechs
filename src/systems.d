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
            if (ent.isRegistered!Acceleration) {
                auto accel = ent.component!Acceleration;
                vel.linear = vel.linear + accel.linear * time;
                vel.angular = vel.angular + accel.angular * time;
            }

            trans.pos = trans.pos + vel.linear * time;
            trans.angle = trans.angle + vel.angular * time;
        }
    }
}

class UnitCollisionSystem : System {
}

class InputSystem : System, Receiver!AllegroEvent {
    private Entity _player;
    enum playerAccel = 50;

    this(Entity player) {
        _player = player;
    }

    override void run(EntityManager es, EventManager events, Duration dt) {
    }

    void receive(AllegroEvent ev) {
        assert(_player.valid);

        auto pos(ALLEGRO_EVENT ev) { return vec2f(ev.mouse.x, ev.mouse.y); }

        auto trans = _player.component!Transform;
        auto accel = _player.component!Acceleration;

        switch (ev.type) {
            case ALLEGRO_EVENT_KEY_DOWN:
                switch (ev.keyboard.keycode) {
                    case ALLEGRO_KEY_W:
                        accel.linear.y = playerAccel;
                        break;
                    case ALLEGRO_KEY_S:
                        accel.linear.y = -playerAccel;
                        break;
                    case ALLEGRO_KEY_A:
                        accel.linear.x = -playerAccel;
                        break;
                    case ALLEGRO_KEY_D:
                        accel.linear.x = playerAccel;
                        break;
                    default:
                }
                break;
            case ALLEGRO_EVENT_KEY_UP:
                switch (ev.keyboard.keycode) {
                    case ALLEGRO_KEY_W:
                    case ALLEGRO_KEY_S:
                        accel.linear.y = 0;
                        break;
                    case ALLEGRO_KEY_A:
                    case ALLEGRO_KEY_D:
                        accel.linear.x = 0;
                        break;
                    default:
                }
                break;
            case ALLEGRO_EVENT_MOUSE_AXES:
                auto disp = pos(ev) - vec2f(screenW, screenH) / 2;
                trans.angle = atan2(disp.y, disp.x);
                break;
            //case ALLEGRO_EVENT_MOUSE_BUTTON_DOWN:
            //    listener.mouseDown(es, ent, pos(ev), ev.mouse.button);
            //    break;
            //case ALLEGRO_EVENT_MOUSE_BUTTON_UP:
            //    listener.mouseUp(es, ent, pos(ev), ev.mouse.button);
            //    break;
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
