module mfellner.exception;

import std.c.stdio : fputs, fputc, stderr;
import derelict.opengl3.gl3;

extern(C) nothrow void glfwPrintError(int error, const(char)* description) {
  fputs(description, stderr);
  fputc('\n', stderr);
}

void glCheckError() {
  if (glGetError() != GL_NO_ERROR) {
     throw new Exception("OpenGL encountered an error!");
  }
}
