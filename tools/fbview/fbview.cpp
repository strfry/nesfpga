#include <stdio.h>
#include <SDL/SDL.h>

#include <vector>

//#undef main

#define WIDTH 320
#define HEIGHT 340

int color_palette[] = {
0x7C7C7C, 0x0000FC, 0x0000BC, 0x4428BC, 0x940084, 0xA80020, 0xA81000, 0x881400, 
0x503000, 0x007800, 0x006800, 0x005800, 0x004058, 0x000000, 0x000000, 0x000000, 
0xBCBCBC, 0x0078F8, 0x0058F8, 0x6844FC, 0xD800CC, 0xE40058, 0xF83800, 0xE45C10, 
0xAC7C00, 0x00B800, 0x00A800, 0x00A844, 0x008888, 0x000000, 0x000000, 0x000000,
0xF8F8F8, 0x3CBCFC, 0x6888FC, 0x9878F8, 0xF878F8, 0xF85898, 0xF87858, 0xFCA044, 
0xF8B800, 0xB8F818, 0x58D854, 0x58F898, 0x00E8D8, 0x787878, 0x000000, 0x000000, 
0xFCFCFC, 0xA4E4FC, 0xB8B8F8, 0xD8B8F8, 0xF8B8F8, 0xF8A4C0, 0xF0D0B0, 0xFCE0A8, 
0xF8D878, 0xD8F878, 0xB8F8B8, 0xB8F8D8, 0x00FCFC, 0xF8D8F8, 0x000000, 0x000000

};

std::vector<SDL_Surface*> g_Frames;

int g_currentFrame = 0;

void load_frames(const char* filename)
{
  FILE* file = fopen(filename, "rb");
  
  if (!file) {
    perror("fopen");
    exit(1);
  }

  int img_len = 256 * 256 * 6;
  
  char img_buf[img_len];
  
  while (fread(img_buf, 1, img_len, file) == img_len) {
     puts("found image");
     
     SDL_Surface* surface = SDL_CreateRGBSurface(SDL_SWSURFACE, WIDTH, HEIGHT, 32, 0xff0000, 0xff00, 0xff, 0);
     SDL_LockSurface(surface);

     for (int y = 0; y < 256; y++) {
       for (int x = 0; x < 256; x++) {
       int pixelValue = 0;
         for (int bit = 0; bit < 6; bit++) {
           switch (img_buf[(y * 256 + x) * 6 + bit]) {
             case 0:
		// TODO: Handle Unknown/Invalid bit value
               break;
             case 2:
               // Zero - do nothing
               break;
             case 3:
               pixelValue += (1 << (5 - bit));
               break;
             default:
               printf("Unknown bit value %x\n", img_buf[(y * 256 + x) * 6 + bit]);
           }
         }
//         printf("Computed Pixel Value %x\n", pixelValue);
         int* pixels = (int*)surface->pixels;
//         pixels[y * surface->w + x] = pixelValue;
         pixels[(surface->h - 1 - y) * surface->w + (surface->w - x - 1)] = color_palette[pixelValue];
       }
     }

     SDL_UnlockSurface(surface);
     g_Frames.push_back(surface);
  }

}

void draw() {
//    SDL_
    SDL_Surface* video = SDL_GetVideoSurface();

    SDL_BlitSurface(g_Frames[g_currentFrame], 0, video, 0);
}

void updateTitle() {
    char title[256];
    snprintf(title, 256, "Frame %d of %lu", g_currentFrame + 1, g_Frames.size());
    SDL_WM_SetCaption(title, 0);
}

int main(int argc, char* argv[])
{
    if (argc < 2) {
        puts("Usage: fbview simdump.out");
        exit(1);
    }
    
    SDL_Surface *screen;
    SDL_Event event;
  
    if (SDL_Init(SDL_INIT_VIDEO) < 0 ) return 1;

    SDL_EnableKeyRepeat(SDL_DEFAULT_REPEAT_DELAY, SDL_DEFAULT_REPEAT_INTERVAL);
   
    if (!(screen = SDL_SetVideoMode(WIDTH, HEIGHT, 0, SDL_SWSURFACE | SDL_DOUBLEBUF)))
    {
        SDL_Quit();
        return 1;
    }

    load_frames(argv[1]);
    
    int lastTime = SDL_GetTicks();
  
    int running = 1;
    while(running) 
    {

         while(SDL_PollEvent(&event)) 
         {      
              switch (event.type) 
              {
                  case SDL_QUIT:
	                running = 0;
	                break;
                  case SDL_KEYDOWN:
                      switch (event.key.keysym.sym) {
                          case SDLK_q:                    
		                    running = 0;
                            break;
                        case SDLK_LEFT:
                            if (g_currentFrame > 0) g_currentFrame--;
                            updateTitle();
                            break;
                        case SDLK_RIGHT:
                            if (g_currentFrame < g_Frames.size() - 1) g_currentFrame++;
                            updateTitle();
                            break;
                        }
                }
                
         }
         
         
         int curTime = SDL_GetTicks();
         
         float dt = float(curTime - lastTime) / 1000.0;
         lastTime = curTime;
         draw();
        SDL_Flip(screen);
        
        SDL_Delay(15);

        
    }
    SDL_Quit();
  
    return 0;
}




