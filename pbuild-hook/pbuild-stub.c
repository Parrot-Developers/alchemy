/**
 */

#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

struct pal_log_dyn_data {
	int* level;
	const char *ident;
	struct pal_log_dyn_data *next;
};

struct pal_lib_desc_data {
	const char *lib;
	const char *desc;
	struct pal_lib_desc_data *next;
};

static struct pal_log_dyn_data *pal_log_dyn_head = NULL;
static struct pal_lib_desc_data *pal_lib_desc_head = NULL;

/**
 * Register a dynamic level.
 * @param data : level data. No copy is done, so it shall reside in memory
 * until the end of the program. It is also modified when added in the linked
 * list.
 * @remarks : it is not thread safe so it shall only be called during init
 */
void pal_log_dyn_add(struct pal_log_dyn_data *data)
{
	data->next = pal_log_dyn_head;
	pal_log_dyn_head = data;
}

/**
 */
int pal_log_dyn_set_level(const char *ident, int level)
{
	int ret = -1;
	struct pal_log_dyn_data *data = pal_log_dyn_head;

	/* the level can be found several times, update all pointers */
	while (data != NULL) {
		if (strcmp(data->ident, ident) == 0) {
			*data->level = level;
			ret = 0;
		}
		data = data->next;
	}
	return ret;
}

/**
 */
int pal_log_dyn_get_level(const char *ident)
{
	struct pal_log_dyn_data *data = pal_log_dyn_head;

	/* only get value of first level found */
	while (data != NULL) {
		if (strcmp(data->ident, ident) == 0) {
			return *data->level;
		}
		data = data->next;
	}

	/* not found */
	return -1;
}

/**
 * TODO
 */
int pal_log_dyn_get_modules(const char **modules[])
{
	static const char **__modules = {NULL};

	if (modules != NULL) {
		*modules = __modules;
		return 0;
	}

	return -1;
}

/**
 * Get the description of a library.
 * @param lib : library to query.
 * @return description of the library.
 */
const char *pal_lib_desc_get(const char *lib)
{
	struct pal_lib_desc_data *data = pal_lib_desc_head;

	while (data != NULL) {
		if (strcmp(data->lib, lib) == 0) {
			return data->desc;
		}
		data = data->next;
	}

	/* not found */
	return NULL;
}

/**
 * Register a library description.
 * @param data : library data. No copy is done, so it shall reside in memory
 * until the end of the program. It is also modified when added in the linked
 * list.
 * @remarks : it is not thread safe so it shall only be called during init
 */
void pal_lib_desc_add(struct pal_lib_desc_data *data)
{
	const char *desc = pal_lib_desc_get(data->lib);

	/* only add if not already present */
	if (desc == NULL || strcmp(desc, data->desc) != 0) {
		data->next = pal_lib_desc_head;
		pal_lib_desc_head = data;
	}
}

/**
 * TODO
 */
void pal_lib_print_table(void)
{
}

/**
 * Get the number of entries in library description table.
 * @return number of entries.
 */
int pal_lib_desc_get_table_size(void)
{
	int size = 0;
	struct pal_lib_desc_data *data = pal_lib_desc_head;

	/* count number of entries */
	while (data != NULL) {
		size++;
		data = data->next;
	}

	return size;
}

/**
 * Get information about a library.
 * @param idx : index in the table.
 * @param lib : variable where to store library name.
 * @param desc : variable where to store library description.
 * return 0 in case of success, -1 otherwise.
 */
int pal_lib_desc_get_table_entry(int idx, const char **lib, const char **desc)
{
	struct pal_lib_desc_data *data = pal_lib_desc_head;

	/*  check parameters */
	if (idx < 0 || lib == NULL || desc == NULL)
		return -1;

	/* search given index */
	while (data != NULL && idx > 0) {
		idx--;
		data = data->next;
	}

	if (data == NULL)
		return -1;

	*lib = data->lib;
	*desc = data->desc;
	return 0;
}

