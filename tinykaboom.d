import std.stdio;
import std.algorithm : min, max;
import std.math : tan, sqrt, PI, sin, floor;
import std.parallelism : parallel;
import std.range : iota;

enum camera_position = [0, 0, 3];
enum light_position = [10, 10, 10];
enum sphere_radius = 1.5;
enum sphere_color = [1, 1, 1];
enum background_color = [0.2, 0.7, 0.8];
enum noise_amplitude = 1;

enum trace_limit = 128;
enum trace_eps = 0.01;

enum width = 640;
enum height = 480;
enum filename = "./out.ppm";
enum fov = PI / 3.0;
enum eps = 0.1;

alias vec3f = float[3];

// aからbまで線形補間
float lerp(float a, float b, float t)
{
    return a + (b - a) * max(0, min(1, t));
}

float hash(float n)
{
    float x = sin(n) * 43758.5453;
    float h = x - floor(x);
    assert(0 <= h && h <= 1);
    return h;
}

float noise(vec3f x)
{
    vec3f p = [floor(x[0]), floor(x[1]), floor(x[2])];
    vec3f f = [x[0] - p[0], x[1] - p[1], x[1] - p[1]];
    f = f[] * [3 - f[0] * 2, 3 - f[1] * 2, 3 - f[2] * 2].dotp(f);
    float n = [1, 57, 113].dotp(p);
    return lerp(lerp(lerp(hash(n + 0), hash(n + 1), f[0]), lerp(hash(n + 57),
            hash(n + 58), f[0]), f[1]), lerp(lerp(hash(n + 113), hash(n + 114),
            f[0]), lerp(hash(n + 170), hash(n + 171), f[0]), f[1]), f[2]);
}

vec3f rotate(vec3f v)
{
    return [[0.00, 0.80, 0.60].dotp(v), [-0.80, 0.36, -0.48].dotp(v),
        [-0.60, -0.48, 0.64].dotp(v)];
}

float fractalBrownianNotion(vec3f x)
{
    float f = 0;

    vec3f p = rotate(x);
    // vec3f p = x;
    f += 0.5000 * noise(p);

    p = p[] * 2.32;
    f += 0.2500 * noise(p);

    p = p[] * 3.03;
    f += 0.1250 * noise(p);

    p = p[] * 2.61;
    f += 0.0625 * noise(p);

    return f / 0.9375;
}

vec3f normalize(vec3f v)
{
    vec3f w = v[] / sqrt(dotp(v, v));
    return w;
}

float dotp(vec3f lhs, vec3f rhs)
{
    float sum = 0;
    foreach (i; 0 .. 3)
        sum += lhs[i] * rhs[i];
    return sum;
}

float norm(vec3f v)
{
    return sqrt(dotp(v, v));
}

float signedDistance(vec3f p)
{
    float displacement = -fractalBrownianNotion([p[0] * 3.4, p[1] * 3.4, p[2] * 3.4,])
        * noise_amplitude;
    return p.norm() - (sphere_radius + displacement);
}

bool traceSphere(vec3f orig, vec3f dir, ref vec3f pos)
{
    bool b = dotp(orig, orig) - dotp(orig, dir) ^^ 2 > sphere_radius ^^ 2;
    if (b)
        return false;
    pos = orig;
    foreach (i; 0 .. trace_limit)
    {
        float d = signedDistance(pos);
        if (d < 0)
            return true;
        pos[] = pos[] + dir[] * max(d * 0.1, trace_eps);
    }
    return false;
}

vec3f distanceFieldNormal(vec3f pos)
{
    float d = signedDistance(pos);
    float nx = signedDistance([pos[0] + eps, pos[1], pos[2]]) - d;
    float ny = signedDistance([pos[0], pos[1] + eps, pos[2]]) - d;
    float nz = signedDistance([pos[0], pos[1], pos[2] + eps]) - d;
    return normalize([nx, ny, nz]);
}

void main()
{
    auto framebuffer = new vec3f[](width * height);

    foreach (j; iota(height).parallel())
        foreach (i; 0 .. width)
        {
            float dir_x = (i + 0.5) - (width / 2.0);
            float dir_y = -(j + 0.5) + (height / 2.0);
            float dir_z = -height / (2.0 * tan(fov / 2.0));
            vec3f hit;
            bool b = traceSphere(camera_position, normalize([dir_x, dir_y, dir_z]), hit);
            if (b)
            {
                vec3f light_dir = light_position[] - hit[];
                light_dir = light_dir.normalize();
                float light_intensity = distanceFieldNormal(hit).dotp(light_dir).max(0.4);

                framebuffer[i + j * width] = sphere_color * light_intensity;
            }
            else
            {
                framebuffer[i + j * width] = background_color;
            }
        }

    auto ofile = File(filename, "w"); // write
    ofile.writeln("P6");
    ofile.writeln(width, " ", height);
    ofile.writeln(255);

    foreach (i; 0 .. width * height)
        foreach (j; 0 .. 3)
            ofile.write(cast(char)(255 * framebuffer[i][j].min(1.0).max(0.0)));

    ofile.close();

}
