"""NES input, frame pacing and save failures using strict, offline hardware fakes."""

import array
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

from apps import nes as adapter


KEYS = {name: name for name in (
    'BUTTON_UP', 'BUTTON_DOWN', 'BUTTON_LEFT', 'BUTTON_RIGHT',
    'BUTTON_SELECT', 'BUTTON_BACK', 'BUTTON_MENU', 'BUTTON_HOME')}


class Controls:
    def __init__(self):
        self.down = set()
        self.edges = set()
        self.xy = types.SimpleNamespace(x=0, y=0)

    def held(self, key):
        return key in self.down

    def pressed(self, key):
        return key in self.edges

    def direction(self):
        return self.xy


class Badge:
    def __init__(self):
        # Native APIs are objects, deliberately not badge.pad()/buttons().
        self.pad = Controls()
        self.buttons = Controls()
        self.ticks_delta = 16.667
        self.lights = []

    def caselights(self, *levels):
        self.lights.append(levels)


class Screen:
    def __init__(self):
        self.raw = bytearray(320 * 240 * 2)
        self.rectangles = []
        self.pen = None

    def rectangle(self, *bounds):
        self.rectangles.append(bounds)


class Core:
    def __init__(self, battery=False):
        self.has_battery = battery
        self.mem = bytearray(32768)
        self.steps = []
        self.draws = 0

    def step_frame(self, mask):
        self.steps.append(mask)

    def render(self, framebuffer, palette, pixel_bytes, scanlines):
        if len(framebuffer) != 153600 or len(palette) != 32:
            raise ValueError('wrong framebuffer or palette')
        if pixel_bytes != 2 or scanlines:
            raise ValueError('expected unfiltered RGB565')
        self.draws += 1


class InputTests(unittest.TestCase):
    def setUp(self):
        self.badge = Badge()
        self.input = adapter.Inputs(self.badge, KEYS)

    def test_touch_ab_are_simultaneous_and_independent(self):
        for keys, mask in ((('BUTTON_BACK',), 1), (('BUTTON_SELECT',), 2),
                           (('BUTTON_BACK', 'BUTTON_SELECT'), 3)):
            with self.subTest(keys=keys):
                self.badge.pad.down = set(keys)
                event = self.input.read(1)
                self.assertEqual(event['mask'], mask)
                self.assertFalse(event['pause'])

    def test_physical_controls_and_home_are_distinct_from_touch_start(self):
        self.badge.buttons.down = {'BUTTON_SELECT', 'BUTTON_UP', 'BUTTON_RIGHT', 'BUTTON_HOME'}
        self.badge.buttons.edges = {'BUTTON_HOME'}
        event = self.input.read(.02)
        self.assertEqual(event['mask'], 1 | 16 | 128)
        self.assertTrue(event['home'])
        self.badge.buttons.down.clear()
        self.badge.buttons.edges.clear()
        self.badge.pad.down = {'BUTTON_HOME'}
        event = self.input.read(.02)
        self.assertEqual(event['mask'], 8)
        self.assertFalse(event['home'])

    def test_pad_vector_diagonal_and_opposite_axis_cancellation(self):
        self.badge.pad.xy.x, self.badge.pad.xy.y = -.8, .8
        self.assertEqual(self.input.read(.02)['mask'], 64 | 32)
        self.badge.buttons.down = {'BUTTON_RIGHT', 'BUTTON_UP'}
        self.assertEqual(self.input.read(.02)['mask'], 0)

    def test_pause_requires_observed_hold_and_both_released_to_rearm(self):
        self.badge.pad.down = {'BUTTON_MENU', 'BUTTON_HOME'}
        self.assertFalse(self.input.read(10)['pause'])
        self.assertFalse(self.input.read(.35)['pause'])
        self.assertTrue(self.input.read(.35)['pause'])
        self.assertFalse(self.input.read(1)['pause'])
        self.badge.pad.down.remove('BUTTON_HOME')
        self.assertFalse(self.input.read(.01)['pause'])
        self.badge.pad.down.add('BUTTON_HOME')
        self.assertFalse(self.input.read(.01)['pause'])
        self.assertFalse(self.input.read(1)['pause'])
        self.badge.pad.down.clear()
        self.input.read(.01)
        self.badge.pad.down = {'BUTTON_MENU', 'BUTTON_HOME'}
        self.assertFalse(self.input.read(.01)['pause'])
        self.assertTrue(self.input.read(.7)['pause'])


class AdapterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'roms').mkdir()
        (self.root / 'roms' / 'original.nes').write_bytes(b'original fake cartridge')
        self.entry = {'file': 'original.nes', 'title': 'Original', 'error': '',
                      'meta': {'mapper': 0, 'size': 24592}}
        self.badge = Badge()
        self.screen = Screen()
        namespace = dict(KEYS, badge=self.badge, screen=self.screen,
                         color=types.SimpleNamespace(rgb=lambda *rgb: rgb))
        with patch.object(adapter, 'discover', return_value=[self.entry]):
            self.app = adapter.NESApp(namespace, str(self.root), str(self.root / 'state'))
        self.app.palette = array.array('H', [0] * 32)
        self.app.hw_palette = array.array('H', range(64))

    def game(self, battery=False):
        self.core = Core(battery)
        self.app.nes = self.core
        self.app.active = self.entry
        self.app.sram_path = str(self.root / 'state' / 'fixture.sav')
        self.app.last_sram = bytes(8192) if battery else None
        self.app.mode = 'game'
        self.app.skip_game_elapsed = False
        return self.core

    def choose(self):
        self.badge.pad.edges = {'BUTTON_BACK'}
        self.app.update()
        self.badge.pad.edges.clear()

    def test_game_rate_is_bounded_and_catchup_renders_once(self):
        core = self.game()
        self.badge.pad.down = {'BUTTON_BACK', 'BUTTON_SELECT'}
        for _ in range(60):
            self.app.update()
        self.assertEqual(len(core.steps), 60)
        self.assertEqual(core.draws, 60)
        self.assertEqual(set(core.steps), {3})
        self.assertEqual(self.app.fps, 60)
        self.badge.ticks_delta = 2000
        self.app.update()
        self.assertEqual(len(core.steps), 62)
        self.assertEqual(core.draws, 61)
        self.badge.ticks_delta = 0
        self.app.update()
        self.assertEqual(len(core.steps), 62)

    def test_fast_callbacks_accumulate_and_fps_counts_displayed_frames(self):
        core = self.game()
        self.badge.ticks_delta = 5
        for _ in range(200):
            self.app.update()
        self.assertEqual(len(core.steps), 59)
        self.assertEqual(core.draws, 59)
        self.app.resume_clock()
        self.app.skip_game_elapsed = False
        self.badge.ticks_delta = 100
        for _ in range(10):
            self.app.update()
        # Floating point may put the one-second boundary at the next callback.
        self.app.update()
        self.assertEqual(self.app.fps, 10)

    def test_fps_includes_full_stall_elapsed_time(self):
        self.game()
        self.badge.ticks_delta = 100
        for _ in range(9):
            self.app.update()
        self.badge.ticks_delta = 2000
        self.app.update()
        self.assertEqual(self.app.fps, round(10 / 2.9))

    def test_launch_and_resume_do_not_spend_loading_time_as_game_time(self):
        fake_core = Core()
        module = types.SimpleNamespace(NES=Mock(return_value=fake_core), NES_PALETTE=[])
        with patch.dict(sys.modules, {adapter.__name__ + '.emu': module}):
            self.assertTrue(self.app.launch(0))
        self.badge.ticks_delta = 4000
        self.app.update()
        self.assertEqual(fake_core.steps, [])
        self.badge.ticks_delta = 16.667
        self.app.update()
        self.assertEqual(len(fake_core.steps), 1)
        self.app.pause()
        self.badge.ticks_delta = 8000
        self.choose()
        self.assertEqual(self.app.mode, 'game')
        self.app.update()
        self.assertEqual(len(fake_core.steps), 1)
        self.badge.ticks_delta = 16.667
        self.app.update()
        self.assertEqual(len(fake_core.steps), 2)

    def test_failed_restart_retains_unsaved_ram_until_successful_retry(self):
        core = self.game(battery=True)
        core.mem[0x4000] = 42
        original_snapshot = self.app.last_sram
        with patch.object(adapter, 'save_sram', side_effect=OSError('disk full')) as save:
            self.app.pause()
            self.app.pause_index = 1
            self.choose()
        self.assertEqual(save.call_count, 2)
        self.assertIs(self.app.nes, core)
        self.assertEqual(core.mem[0x4000], 42)
        self.assertEqual(self.app.last_sram, original_snapshot)
        self.assertEqual(self.app.mode, 'pause')
        self.assertIn('SAVE FAILED', self.app.error)
        with patch.object(adapter, 'save_sram', return_value=True) as save:
            self.assertTrue(self.app.persist())
            self.assertTrue(self.app.persist())
        save.assert_called_once()
        self.assertEqual(self.app.last_sram[0], 42)
        self.assertEqual(self.app.error, '')

    def test_periodic_save_failure_is_visible_and_preserves_live_core(self):
        core = self.game(battery=True)
        core.mem[0x4000] = 99
        self.app.save_elapsed = 60
        with patch.object(adapter, 'save_sram', side_effect=OSError('read only')), \
                patch.object(self.app, 'draw_pause', wraps=self.app.draw_pause) as draw:
            self.app.update()
        self.assertIs(self.app.nes, core)
        self.assertEqual(self.app.mode, 'pause')
        self.assertTrue(self.app.save_error)
        draw.assert_called_once()

    def test_failed_save_blocks_library_and_cooperative_home_exit(self):
        core = self.game(battery=True)
        core.mem[0x4000] = 7
        self.app.mode = 'pause'
        self.app.pause_index = 2
        with patch.object(adapter, 'save_sram', side_effect=OSError('disk full')):
            self.choose()
            self.assertEqual(self.app.mode, 'pause')
            self.badge.buttons.edges = {'BUTTON_HOME'}
            self.assertIsNone(self.app.update())
        self.assertIs(self.app.nes, core)
        self.assertEqual(self.badge.lights[-1], (0, 0, 0, 0))
        with patch.object(adapter, 'save_sram', return_value=True):
            self.assertEqual(self.app.update(), 'menu')

    def test_stock_exit_failure_is_reported_without_claiming_to_veto_irq(self):
        core = self.game(battery=True)
        core.mem[0x4000] = 1
        with patch.object(adapter, '_app', self.app), \
                patch.object(adapter, 'save_sram', side_effect=OSError('disk full')), \
                patch('builtins.print') as output:
            adapter.on_exit()
        self.assertIn('NES SAVE FAILED', output.call_args.args[0])
        self.assertIs(self.app.nes, core)

    def test_bad_saved_ram_fails_closed_without_overwriting_file(self):
        module = types.SimpleNamespace(NES=Mock(return_value=Core(True)), NES_PALETTE=[])
        with patch.dict(sys.modules, {adapter.__name__ + '.emu': module}), \
                patch.object(adapter, 'load_sram', side_effect=ValueError('corrupt SRAM')), \
                patch.object(adapter, 'save_sram') as save:
            self.assertFalse(self.app.launch(0))
        self.assertIsNone(self.app.nes)
        self.assertEqual(self.app.mode, 'error')
        self.assertIn('corrupt SRAM', self.app.error)
        save.assert_not_called()

    def test_menu_redraws_once_and_return_from_error_draws_immediately(self):
        with patch.object(self.app, 'library', wraps=self.app.library) as draw:
            self.app.update()
            self.app.update()
            draw.assert_called_once()
            self.app.mode = 'error'
            self.app.error = 'Original test error'
            self.app.dirty = True
            with patch.object(self.app, 'draw_error', wraps=self.app.draw_error) as error:
                self.app.update()
                self.app.update()
                error.assert_called_once()
            self.choose()
            self.assertEqual(self.app.mode, 'library')
            self.assertEqual(draw.call_count, 2)

    def test_pause_library_transition_draws_in_same_update(self):
        self.game()
        self.app.mode = 'pause'
        self.app.pause_index = 2
        with patch.object(self.app, 'library', wraps=self.app.library) as draw:
            self.choose()
        self.assertEqual(self.app.mode, 'library')
        self.assertIsNone(self.app.nes)
        draw.assert_called_once()


if __name__ == '__main__':
    unittest.main()
