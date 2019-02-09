import std.stdio;
import std.algorithm : min, max;
import std.math : tan, sqrt, PI;
import std.parallelism : parallel;
import std.range : iota;

enum sphere_radius = 1.5;
enum trace_limit = 128;

alias vec3f = float[3];

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
    return p.norm() - sphere_radius;
}

bool traceSphere(vec3f orig, vec3f dir, ref vec3f pos)
{
    pos = orig;
    foreach (i; 0 .. trace_limit)
    {
        float d = signedDistance(pos);
        if (d < 0)
            return true;
        pos[] = pos[] + dir[] * max(d * 0.1, 0.01);
    }
    return false;
}

void main()
{
    enum width = 640;
    enum height = 480;
    enum filename = "./out.ppm";
    enum fov = PI / 3.0;

    auto framebuffer = new vec3f[](width * height);

    foreach (j; iota(height).parallel())
        foreach (i; 0 .. width)
        {
            float dir_x = (i + 0.5) - (width / 2.0);
            float dir_y = -(j + 0.5) + (height / 2.0);
            float dir_z = -height / (2.0 * tan(fov / 2.0));
            vec3f hit;
            bool b = traceSphere([0, 0, 3], normalize([dir_x, dir_y, dir_z]), hit);
            if (b)
            {
                framebuffer[i + j * width] = [1, 1, 1];
            }
            else
            {
                framebuffer[i + j * width] = [0.2, 0.7, 0.8];
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
