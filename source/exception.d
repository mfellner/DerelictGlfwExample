module mfellner.exception;

import core.stdc.stdio : fputs, fputc, stderr;
import derelict.opengl;

extern(C) nothrow void glfwPrintError(int error, const(char)* description) {
  fputs(description, stderr);
  fputc('\n', stderr);
}

void glCheckError() {
  if (glGetError() != GL_NO_ERROR) {
     throw new Exception("OpenGL encountered an error!");
  }
}
