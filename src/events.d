module events;

import entitysysd;
import allegro5.allegro;

import common;

@event:

/// Wraps an allegro-generated event to pass it through the ECS event framework
struct AllegroEvent {
    ALLEGRO_EVENT ev;
    alias ev this;
}
