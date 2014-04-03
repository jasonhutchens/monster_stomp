#!/usr/bin/env ruby

require "rubygems"
require "rubygame"
require "nokogiri"

class Player
    include Rubygame::Sprites::Sprite
    attr_writer :joy
    def initialize(position, name, blobs)
        super()
        blob = blobs["#{name}_stand"]
        @image = blob[:surface]
        @rect = Rubygame::Rect.new(position, blob[:size])
        @x = @rect.x.to_f
        @y = @rect.y.to_f
        @dx = 0.0
        @dy = 0.0
        @joy = 0.0
        @standing = false
        @frame = 0
        @dist = 0.0
        @stun = 0.0
        @wake = 0.5
        @dying = 0.0
        @origin = [@x, @y]
        @speed = 0
    end
    def collect(fruit)
    end
    def start
        @x = @origin[0]
        @y = @origin[1]
    end
    def update(dt, bounds)
        if @dying > 0.0
            @dying -= dt
            respawn if @dying <= 0
        end
        stop if @dying > 0.0
        @stun -= dt if @stun > 0.0
        @joy = 0.0 if @joy.abs < 0.4
        @dx += @joy * @speed if @standing
        @dx += @joy * 20 unless @standing
        @dx = 300 if @dx > 300
        @dx = -300 if @dx < -300
        @dy += 1000 * dt
        @x += @dx * dt
        @y += @dy * dt
        @dx *= 0.7 if @standing
        @dx *= 0.9 unless @standing
        @rect.x = @x
        @rect.y = @y
        @x = bounds.left - @rect.w if @rect.left > bounds.right
        @x = bounds.right if @rect.right < bounds.left
        @y = bounds.top - @rect.h if @rect.top > bounds.bottom
        @standing = false
        @dist += @dx * dt
        if @dist.abs > 20
            @frame += 1
            @frame %= 2
            @dist = 0
        end
    end
    def stand(rect)
        if @rect.bottom > rect.top && @rect.top < rect.top && @rect.left < rect.right && @rect.right > rect.left
            @dy = 0
            @y = rect.top - @rect.height
            @standing = true
        end
    end
    def hit(rect)
        if @rect.bottom > rect.top && @rect.top < rect.top && @rect.left < rect.right && @rect.right > rect.left
            @dy = 0
            @y = rect.top - @rect.height
            @rect.y = @y
            @standing = true
        end
        if @rect.right > rect.left && @rect.left < rect.left && @rect.top < rect.centery && @rect.bottom > rect.centery
            @x = rect.left - @rect.width
            @dx = 0
            @rect.x = @x
        end
        if @rect.left < rect.right && @rect.right > rect.right && @rect.top < rect.centery && @rect.bottom > rect.centery
            @x = rect.right
            @dx = 0
        end
    end
    def bump(monster)
        return if monster == self
        die if not monster.stunned and not monster.kind_of?(Player)
        hit(monster.rect) unless monster.stunned
        stand(monster.rect) if monster.stunned
    end
    def stop
        @joy = 0
    end
    def stun
        false
    end
    def recover(dt)
        surface = Rubygame::Surface.new(@rect.size, 0, Rubygame::SRCALPHA | Rubygame::SRCCOLORKEY)
        if @stun < 3.0
            @wake -= dt
            @wake = 0.5 if @wake < 0
        end
        surface.alpha = 64 if @wake > 0.25
        surface.colorkey = [0,0,0]
        @image.blit(surface, [0,0])
        @image = surface
    end
    def stunned
        return @stun > 0.0
    end
    def respawn
        @stun = 4.0
        @wake = 0.5
        @dx = 0
        @dy = 0
    end
end

class Hard < Player
    attr_reader :fruits
    def initialize(position, blobs)
        super(position, "hard", blobs)
        @frames = [blobs["hard_1"], blobs["hard_2"]]
        @stomp = false
        @angle = 0.0
        @fruits = Rubygame::Sprites::Group.new
        @fruit_image = blobs['cherry']
        @speed = 50
    end
    def update(dt, blobs, bounds)
        @fruits.update(dt, bounds)
        super(dt, bounds)
        @image = @frames[@frame][:surface]
        @image = blobs["hard_stand"][:surface] if @dx.abs < 20
        @image = blobs["hard_stomp"][:surface] if @stomp or @dying > 0.0
        @image = @image.flip(true, false) if @dx > 0
        @image = @image.rotozoom(@angle, 1.0) if @dying > 0.0
        @angle += 900 * dt if @dying > 0.0
        recover(dt) if @stun > 0.0
    end
    def draw(screen)
        super
        @fruits.draw(screen)
    end
    def fire
        @dy -= 400 if @standing
        @dy += 250 unless @standing
        @dx /= 4 unless @standing
        @stomp = true unless @standing
    end
    def hit(rect)
        return if @dying > 0.0
        super
        @stomp = false
    end
    def die
        return if @dying > 0.0 or @stun > 0.0
        @dying = 1.3
        @dy = -600
        @dx *= -10000
        @angle = 0.0
    end
    def respawn
        start
        super
    end
    def bump(monster)
        monster.fall if monster.kind_of?(Soft) and @stomp
        if monster.stunned and @rect.bottom < monster.rect.centery and @stomp
            (0..4).each do
                fruit = Fruit.new([monster.rect.x, monster.rect.y - 16], @fruit_image)
                fruit.dy = -100 -rand(200)
                fruit.dx = rand(4000) - rand(4000)
                @fruits << fruit
            end
            monster.die
        end
        super
    end
end

class Bullet
    include Rubygame::Sprites::Sprite
    attr_writer :dx
    def initialize(position, blob)
        super()
        @rect = Rubygame::Rect.new(position, blob[:size])
        @image = blob[:surface]
        @x = @rect.x.to_f
        @dx = 0
    end
    def update(dt, bounds)
        @x += @dx * dt
        kill if @rect.centerx < bounds.left
        kill if @rect.centerx > bounds.right
        @rect.x = @x
        @col_rect = @rect.inflate(-16, -16)
    end
    def hit(rect)
        kill
    end
    def stun(monster)
        hit(monster.rect) if monster.stun
    end
end

class Fruit
    include Rubygame::Sprites::Sprite
    attr_writer :dx, :dy
    def initialize(position, blob)
        super()
        @rect = Rubygame::Rect.new(position, blob[:size])
        @image = blob[:surface]
        @x = @rect.x.to_f
        @y = @rect.y.to_f
        @dx = 0
        @dy = 0
        @flying = true
    end
    def collect
        kill if not @flying
    end
    def update(dt, bounds)
        @x += @dx * dt
        @y += @dy * dt
        @dy += 400 * dt
        @dx *= 0.8
        @x = bounds.left - @rect.w if @rect.left > bounds.right
        @x = bounds.right if @rect.right < bounds.left
        @y = bounds.top - @rect.h if @rect.top > bounds.bottom
        @rect.x = @x
        @rect.y = @y
    end
    def hit(rect)
        return unless @dy > 0
        if @rect.bottom > rect.top && @rect.top < rect.top && @rect.left < rect.right && @rect.right > rect.left
            @dy = 0
            @y = rect.top - @rect.height
            @flying = false
        end
        if @rect.right > rect.left && @rect.left < rect.left && @rect.top < rect.bottom && @rect.bottom > rect.top
            @x = rect.left - @rect.width
            @dx = 0
        end
        if @rect.left < rect.right && @rect.right > rect.right && @rect.top < rect.bottom && @rect.bottom > rect.top
            @x = rect.right
            @dx = 0
        end
    end
    def stun(monster)
        hit(monster.rect) if monster.stun
    end
end

class Soft < Player
    attr_reader :bullets
    def initialize(position, blobs)
        super(position, "soft", blobs)
        @frames = [blobs["soft_1"], blobs["soft_2"]]
        @bullets = Rubygame::Sprites::Group.new
        @bullet_image = blobs['bullet']
        @left = true
        @falling = false
        @speed = 80
    end
    def collect(fruit)
        fruit.collect
    end
    def update(dt, blobs, bounds)
        if @falling
            @y += 64
            @falling = false
        end
        super(dt, bounds)
        @image = @frames[@frame][:surface]
        @image = blobs["soft_stand"][:surface] if @dx.abs < 20
        @image = blobs["soft_tumble"][:surface] if @dying > 0.0
        @image = blobs["soft_asleep"][:surface] if @dying > 0.0 and @dx.abs < 20
        @left = @dx <= 0
        @image = @image.flip(true, false) unless @left
        @bullets.update(dt, bounds)
        recover(dt) if @stun > 0.0
    end
    def fire
        return if @dying > 0.0
        bullet = Bullet.new([@rect.x, @rect.y], @bullet_image)
        bullet.dx = -600 if @left
        bullet.dx = 600 unless @left
        @bullets << bullet
    end
    def draw(screen)
        super
        @bullets.draw(screen)
    end
    def die
        return
        return if @dying > 0.0 or @stun > 0.0
        @dying = 3.0
    end
    def fall
        @falling = true
    end
end

class Platform
    include Rubygame::Sprites::Sprite
    def initialize(position, tile)
        super()
        @rect = Rubygame::Rect.new(position, tile[:size])
        @image = tile[:surface]
    end
end

class Collision
    include Rubygame::Sprites::Sprite
    def initialize(rect)
        super()
        @rect = rect
    end
end

class Monster
    include Rubygame::Sprites::Sprite
    def initialize(position, name, blobs)
        super()
        @frames = [blobs["#{name}_1"], blobs["#{name}_2"]]
        @frame = 0
        @dist = 0.0
        @image = @frames[0][:surface]
        @rect = Rubygame::Rect.new(position, @frames[0][:size])
        @x = @rect.x.to_f
        @y = @rect.y.to_f
        @dx = 0.0
        @dy = 0.0
        @stun = 0.0
        @wake = 0.5
    end
    def collect(fruit)
    end
    def stunned
        @stun > 0.0
    end
    def update(dt, bounds)
        @stun -= dt if @stun > 0.0
        @x += @dx * dt
        @y += @dy * dt
        @dist += @dx * dt
        if @dist.abs > 7
            @frame += 1
            @frame %= 2
            @dist = 0
        end
        @rect.x = @x
        @rect.y = @y
        if @rect.left < bounds.left
            @dx = -@dx
            @x = bounds.left
        end
        if @rect.right > bounds.right
            @dx = -@dx
            @x = bounds.right - @rect.w
        end
        @y = bounds.top - @rect.h if @rect.top > bounds.bottom
        @image = @frames[@frame][:surface]
        @image = @image.flip(true, false) if @dx > 0
        if @stun > 0.0
            surface = Rubygame::Surface.new(@rect.size, 0, Rubygame::SRCALPHA | Rubygame::SRCCOLORKEY)
            if @stun < 3.0
                @wake -= dt
                @wake = 0.5 if @wake < 0
            end
            surface.alpha = 64 if @wake > 0.25
            surface.colorkey = [0,0,0]
            @image.blit(surface, [0,0])
            @image = surface
        end
    end
    def hit(rect)
        if @rect.bottom > rect.top && @rect.top < rect.top && @rect.left < rect.right && @rect.right > rect.left
            @dy = -@dy / 4
            @y = rect.top - @rect.height
        elsif @rect.right > rect.left && @rect.left < rect.left && @rect.top < rect.bottom && @rect.bottom > rect.top
            @dx = -@dx
            @x = rect.left - @rect.width
        elsif @rect.left < rect.right && @rect.right > rect.right && @rect.top < rect.bottom && @rect.bottom > rect.top
            @dx = -@dx
            @x = rect.right
        end
    end
    def bump(monster)
        return if stunned or monster.stunned
        if @rect.top < monster.rect.centery
            @dx = -@dx if @rect.centerx < monster.rect.centerx && @dx > 0
            @dx = -@dx if @rect.centerx > monster.rect.centerx && @dx < 0
        end
    end
    def stun
        @stun += 4.0
        @wake = 0.5
    end
    def die
        kill
    end
end

class Bomb < Monster
    def initialize(position, blobs)
        super(position, 'bomb', blobs)
        @dx = 30
    end
    def update(dt, blobs, bounds)
        @dy += 500 * dt
        super(dt, bounds)
    end
end

class Dart < Monster
    def initialize(position, blobs)
        super(position, 'dart', blobs)
        @dx = -20
    end
    def update(dt, blobs, bounds)
        @dy += 400 * dt
        super(dt, bounds)
    end
end

class Bird < Monster
    def initialize(position, blobs)
        super(position, 'bird', blobs)
        @dx = -60
    end
    def update(dt, blobs, bounds)
        super(dt, bounds)
    end
end

class Level
    attr_reader :title, :width, :height, :hard, :soft
    def initialize(path, tiles, blobs, top_left)
        blob = File.open(path) { |file| file.read }
        doc = Nokogiri.XML(blob)
        @title = doc.search('level').first['title']
        @width = doc.search('width').first.content.to_i
        @height = doc.search('height').first.content.to_i
        @layers = {}
        ['background', 'platforms', 'foreground'].each do |name|
            @layers[name] = load_layer(doc, name, tiles, top_left)
        end 
        @platforms = Rubygame::Sprites::Group.new
        load_static(doc, tiles, top_left)
        @hard = nil
        @soft = nil
        @monsters = Rubygame::Sprites::Group.new
        load_objects(doc, blobs, top_left)
        @bounds = Rubygame::Rect.new(top_left, [@width, @height])
    end
    def win
        @monsters.length == 2 and @hard.fruits.length == 0 and @soft.bullets.length == 0
    end
    def start(screen, tiles)
        @hard.start
        @soft.start
        render_layer('background', screen, tiles)
    end
    def render(screen, tiles)
        render_layer('platforms', screen, tiles)
        @monsters.draw(screen)
        render_layer('foreground', screen, tiles)
    end
    def update(dt, blobs)
        @monsters.update(dt, blobs, @bounds)
        @monsters.collide_group(@monsters) { |bump1, bump2| bump1.bump(bump2) }
        @monsters.collide_group(@soft.bullets) { |monster, bullet| bullet.stun(monster) }
        @monsters.collide_group(@hard.fruits) { |monster, fruit| monster.collect(fruit) }
        @platforms.collide_group(@soft.bullets) { |platform, bullet| bullet.hit(platform.rect) }
        @platforms.collide_group(@hard.fruits) { |platform, fruit| fruit.hit(platform.rect) }
        @platforms.collide_group(@monsters) { |platform, monster| monster.hit(platform.rect) }
    end
  private
    def load_layer(doc, name, tiles, top_left)
        layer = []
        default = doc.search(name).first['set']
        doc.search(name).first.search('tile').each do |tile|
            set = tile['set']
            set = default unless set
            size = tiles[set][:size]
            source = Rubygame::Rect.new([tile['tx'].to_i, tile['ty'].to_i], size)
            target = [tile['x'].to_i + top_left[0], tile['y'].to_i + top_left[1]]
            layer << {set: set, source: source, target: target}
        end
        return layer
    end
    def load_static(doc, tiles, top_left)
        doc.search('rect').each do |rect|
            @platforms << Collision.new(Rubygame::Rect.new(rect['x'].to_i + top_left[0], rect['y'].to_i + top_left[1], rect['w'].to_i, rect['h'].to_i))
        end
    end
    def load_objects(doc, blobs, top_left)
        doc.search('objects').first.children.each do |object|
            next if object.name == "text"
            target = [object['x'].to_i + top_left[0], object['y'].to_i + top_left[1]]
            case object.name
                when 'bomb' then @monsters << Bomb.new(target, blobs)
                when 'dart' then @monsters << Dart.new(target, blobs)
                when 'bird' then @monsters << Bird.new(target, blobs)
                when 'hard' then @hard = Hard.new(target, blobs)
                when 'soft' then @soft = Soft.new(target, blobs)
            end
        end
        @monsters << @hard
        @monsters << @soft
    end
    def render_layer(name, screen, tiles)
        @layers[name].each do |tile|
            surface = tiles[tile[:set]][:surface]
            surface.blit(screen, tile[:target], tile[:source])
        end
    end
end

class World
    attr_reader :title, :width, :height
    def initialize(path)
        blob = File.open(path) { |file| file.read }
        doc = Nokogiri.XML(blob)
        @title = doc.search('name').first.content
        @width = doc.search('defaultWidth').first.content.to_i
        @height = doc.search('defaultHeight').first.content.to_i
        path = File.dirname(path)
        gfx = File.join(path, doc.search('workingDirectory').first.content)
        @tiles = {}
        doc.search('tileset').each do |node|
            surface = Rubygame::Surface.load(File.join(gfx,node['image']))
            @tiles[node['name']] = { surface: surface, size: [node['tileWidth'].to_i, node['tileHeight'].to_i] }
        end
        @blobs = {}
        doc.search('object').each do |node|
            Dir.new(gfx).each do |name|
                next unless name =~ /^(#{node['name']}.*)\.png$/
                surface = Rubygame::Surface.load(File.join(gfx,name))
                @blobs[Regexp.last_match(1)] = { surface: surface, size: [node['width'].to_i, node['height'].to_i] }
            end
        end
        @levels = []
        @current = nil
        @current_index = -1
        @hard = nil
        @soft = nil
        @control_hard = false
        @control_soft = false
    end
    def load_levels(path, top_left)
        levels = []
        Dir.new(path).each do |name|
            next unless name =~ /\.oel$/
            levels << name.to_s
        end
        levels.sort!
        levels.each do |name|
            @levels << Level.new(File.join(path, name), @tiles, @blobs, top_left)
        end
    end
    def start(screen, index = 0)
        @current_index = index
        @current = @levels[@current_index]
        @current.start(screen, @tiles)
        @hard = @current.hard
        @soft = @current.soft
    end
    def win
        @current.win
    end
    def next(screen)
        @current_index += 1
        @current_index %= @levels.length
        start(screen, @current_index)
    end
    def update(dt)
        @current.update(dt, @blobs)
    end
    def render(screen)
        @current.render(screen, @tiles)
    end
    def joy(id, value)
        if id == 0
            @hard.joy = value if not @control_soft
            @soft.joy = value if Rubygame::Joystick.num_joysticks == 1 and not @control_hard
            @soft.joy = value if @control_soft and not @control_hard
        else
            @soft.joy = value
        end
    end
    def tri(id, value)
        @control_hard = value > 0.5 if id == 0
        @control_soft = value > 0.5 if id == 1
        @hard.stop if @control_soft
        @soft.stop if @control_hard
    end
    def but(id)
        if id == 0
            @hard.fire if not @control_soft
            @soft.fire if Rubygame::Joystick.num_joysticks == 1 and not @control_hard
            @soft.fire if @control_soft and not @control_hard
        else
            @soft.fire
        end
    end
end

class Game
    include Rubygame::EventHandler::HasEventHandler
    def initialize(framerate, path, full)
        Rubygame.init
        Rubygame::Joystick.activate_all

        @world = World.new(path)

        @width = @world.width + 100
        @width = Rubygame::Screen.get_resolution[0] if full
        @height = @world.height + 100
        @height = Rubygame::Screen.get_resolution[1] if full
        @screen = Rubygame::Screen.new([@width, @height], 0, Rubygame::HWSURFACE | Rubygame::DOUBLEBUF | (full ? Rubygame::FULLSCREEN : 0))
        @screen.title = @world.title
        @screen.show_cursor = false

        @background = Rubygame::Surface.new(@screen.size)
        @background.fill([25,50,100])

        top_left = [(@width - @world.width)/2, (@height - @world.height)/2]
        @background.draw_box(top_left, [top_left[0] + @world.width, top_left[1] + @world.height], [255,0,0])
        @clip = Rubygame::Rect.new(top_left, [@world.width, @world.height])

        @world.load_levels(File.dirname(path), top_left)

        Rubygame::TTF.setup
        ttfont_path = File.join(File.dirname(__FILE__), "FreeSans.ttf")
        @font = Rubygame::TTF.new( ttfont_path, 18 )

        @queue = Rubygame::EventQueue.new
        @queue.enable_new_style_events

        make_magic_hooks({
            escape: :quit,
            q: :quit,
            n: proc { @world.next(@background) },
            joyaxis(0) =>  proc { |owner, event| @world.joy(0, event.value) },
            joyaxis(1) =>  proc { |owner, event| @world.joy(1, event.value ) },
            joytrigger(0) =>  proc { |owner, event| @world.tri(0, event.value) },
            joytrigger(1) =>  proc { |owner, event| @world.tri(1, event.value) },
            joypressed(0) =>  proc { |owner, event| @world.but(0) },
            joypressed(1) =>  proc { |owner, event| @world.but(1) },
            Rubygame::Events::QuitRequested => :quit,
            Rubygame::Events::InputFocusGained  => :update_screen,
            Rubygame::Events::WindowUnminimized => :update_screen,
            Rubygame::Events::WindowExposed     => :update_screen
        })

        @clock = Rubygame::Clock.new
        @clock.target_framerate = framerate if framerate > 0
        @clock.enable_tick_events
        @clock.calibrate
    end
    def go
        @world.start(@background)
        dt = 0
        catch(:quit) do
            loop do
                tick_event = @clock.tick
                dt += tick_event.seconds
                while dt > 0.02
                    update(0.02)
                    dt -= 0.02
                end
                render
                @screen.flip
                @world.next(@screen) if @world.win
            end
        end
        Rubygame.quit
    end
  private
    def joyaxis(id)
        return Rubygame::EventTriggers::AndTrigger.new(
            Rubygame::EventTriggers::InstanceOfTrigger.new(
                Rubygame::Events::JoystickAxisMoved),
                Rubygame::EventTriggers::AttrTrigger.new(:joystick_id => id, :axis => 0))
    end
    def joytrigger(id)
        return Rubygame::EventTriggers::AndTrigger.new(
            Rubygame::EventTriggers::InstanceOfTrigger.new(
                Rubygame::Events::JoystickAxisMoved),
                Rubygame::EventTriggers::AttrTrigger.new(:joystick_id => 0, :axis => 2 + 3*id))
    end
    def joypressed(id)
        return Rubygame::EventTriggers::AndTrigger.new(
            Rubygame::EventTriggers::InstanceOfTrigger.new(
                Rubygame::Events::JoystickButtonPressed),
                Rubygame::EventTriggers::AttrTrigger.new(:joystick_id => id))
    end
    def update(dt)
        @queue.fetch_sdl_events
        @queue.each { |event| handle(event) }
        @world.update(dt)
    end
    def render
        @background.blit(@screen, [0,0])
        @screen.clip = @clip
        @world.render(@screen)
        @screen.clip = nil
        @font.render("%2.2f" % @clock.framerate, true, [250,250,250]).blit(@screen, [@width-60,7])
        @screen.update
    end
    def quit
        throw :quit
    end
    def update_screen
        @screen.update
    end
end

Game.new(0, File.join(".", "LevelData", "monstertag.oep"), true).go
