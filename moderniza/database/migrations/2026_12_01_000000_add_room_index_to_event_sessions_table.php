<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tarea 4 · Cambio de requisito "sin solapes en la sala".
 *
 * La comprobación busca sesiones del mismo evento y sala por horario.
 * Este índice acelera esa consulta. Es reversible: down() lo elimina
 * sin tocar los datos existentes.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('event_sessions', function (Blueprint $table) {
            $table->index(['event_id', 'room', 'starts_at'], 'event_sessions_event_room_start_index');
        });
    }

    public function down(): void
    {
        // MySQL usa este índice para la clave externa event_id (su índice
        // automático desaparece al crear este). Antes de borrarlo se crea un
        // índice solo de event_id; si no, MySQL da el error 1553.
        if (! Schema::hasIndex('event_sessions', ['event_id'])) {
            Schema::table('event_sessions', function (Blueprint $table) {
                $table->index('event_id', 'event_sessions_event_id_index');
            });
        }

        Schema::table('event_sessions', function (Blueprint $table) {
            $table->dropIndex('event_sessions_event_room_start_index');
        });
    }
};
