import std.datetime;

import entitysysd;
import allegro5.allegro;
import allegro5.allegro_image;

import common;
import events;
import systems;
import entities;

void main() {
    /* --- Initialize Allegro --- */
    if (!al_init()) assert(0, "al_init failed!");

    auto display = al_create_display(screenW, screenH);
    auto queue   = al_create_event_queue();

    al_install_keyboard();
    al_install_mouse();
    al_init_image_addon();

    auto fpsTimer = al_create_timer(1.0 / 60);

    al_register_event_source(queue, al_get_display_event_source(display));
    al_register_event_source(queue, al_get_keyboard_event_source());
    al_register_event_source(queue, al_get_mouse_event_source());
    al_register_event_source(queue, al_get_timer_event_source(fpsTimer));

    // allow fading sprites by reducing the alpha against a black background
    with(ALLEGRO_BLEND_MODE)
        al_set_blender(ALLEGRO_BLEND_OPERATIONS.ALLEGRO_ADD, ALLEGRO_ALPHA, ALLEGRO_INVERSE_ALPHA);

    /* --- Load Resources --- */
    auto spritesheet = al_load_bitmap("spritesheet.png");
    assert(spritesheet, "Failed to load spritesheet.png");

    /* --- Initialize EntitySysD --- */
    auto game = new EntitySysD;
    auto player = game.entities.createPlayer();
    game.entities.createMap("map0.json");

    game.systems.register(new MotionSystem);
    game.systems.register(new UnitCollisionSystem);
    game.systems.register(new InputSystem(player));
    game.systems.register(new AnimationSystem);
    game.systems.register(new RenderSystem(spritesheet, player));
    game.systems.register(new WeaponSystem);

    /* --- Game Loop --- */
    al_start_timer(fpsTimer);

    bool exit      = false;
    bool update    = false;
    auto timestamp = MonoTime.currTime;

    while(!exit) {
        /* --- Process events --- */
        ALLEGRO_EVENT event;
        al_wait_for_event(queue, &event);

        // overarching event handling
        switch(event.type) {
            case ALLEGRO_EVENT_TIMER:
                update = update || (event.timer.source == fpsTimer);
                break;
            case ALLEGRO_EVENT_DISPLAY_CLOSE:
                exit = true;
                break;
            default:
        }

        // some systems may handle allegro events directly
        game.events.emit!AllegroEvent(event);

        if (update) {
            /* --- Update and render new frame --- */
            update = false;
            auto now = MonoTime.currTime;
            auto elapsed = now - timestamp;

            al_clear_to_color(al_map_rgb(0,0,0));
            game.systems.run(elapsed);
            al_flip_display();

            timestamp = now;
        }
    }

    /* --- Cleanup --- */
    al_destroy_bitmap(spritesheet);
    al_destroy_display(display);
    al_destroy_event_queue(queue);
}
