/*
 * termios.c -- POSIX terminal attribute functions for GNO/ME
 *
 * cfgetispeed, cfgetospeed, cfsetispeed, cfsetospeed, tcgetattr, tcsetattr
 *
 * On GNO, TIOCGETA/TIOCSETA map to GS/OS TTY device ioctls.
 * speed_t is unsigned char in GNO (see sys/termios.h).
 *
 * $Id: termios.c,v 1.0 2026/04/03 gdr Exp $
 */

#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/termios.h>
#include <errno.h>

speed_t
cfgetospeed(const struct termios *t)
{
	return t->c_ospeed;
}

speed_t
cfgetispeed(const struct termios *t)
{
	return t->c_ispeed;
}

int
cfsetospeed(struct termios *t, speed_t speed)
{
	t->c_ospeed = speed;
	return 0;
}

int
cfsetispeed(struct termios *t, speed_t speed)
{
	t->c_ispeed = speed;
	return 0;
}

int
tcgetattr(int fd, struct termios *t)
{
	return ioctl(fd, TIOCGETA, t);
}

int
tcsetattr(int fd, int action, const struct termios *t)
{
	int cmd;

	switch (action) {
	case TCSANOW:
		cmd = TIOCSETA;
		break;
	case TCSADRAIN:
		cmd = TIOCSETAW;
		break;
	case TCSAFLUSH:
		cmd = TIOCSETAF;
		break;
	default:
		errno = EINVAL;
		return -1;
	}
	return ioctl(fd, cmd, (void *)t);
}
