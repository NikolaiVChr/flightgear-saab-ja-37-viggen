/* Compute JA 37 global elevation map from SRTMGL30 DEM
 *
 * Copyright 2021 Colin Geniet.
 * Licensed under the GNU General Public License 2.0 or any later version.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>
#include <endian.h>
#include <assert.h>


/* Covered area */
#define LON_MIN_DEG	-180
#define LON_MAX_DEG	180
#define LAT_MIN_DEG	-60
#define LAT_MAX_DEG	90


/*
 * Input SRTMGL30 DEM files.
 *
 * File format is GTOPO30 :
 * https://d9-wret.s3.us-west-2.amazonaws.com/assets/palladium/production/s3fs-public/atoms/files/GTOPO30_Readme.pdf
 */

typedef int16_t dem_elev_t;

/*
 * I'm not sure how invalid values are represented.
 * GTOPO30 uses -9999, SRTM uses -32768.
 * Either way, anything out of this range certainly isn't valid.
 */
#define DEM_MIN_VALID	-1000
#define DEM_MAX_VALID	10000
/* My canonical invalid value */
#define DEM_INVALID	INT16_MIN
#define DEM_IS_INVALID(elev)	((elev) < DEM_MIN_VALID || (elev) > DEM_MAX_VALID)
static_assert(DEM_IS_INVALID(DEM_INVALID));

/*
 * Decode GTOPO30 input value.
 *
 * Convert to native byte order (from big endian), and zero invalid values.
 */
dem_elev_t decode_dem_elev(dem_elev_t elev)
{
	elev = be16toh(elev);
	if (DEM_IS_INVALID(elev))
		return 0;
	else
		return elev;
}

#define DEM_ENTRY_SIZE		2       /* bytes per value */
#define DEM_CELL_PER_DEG	120     /* 30 arcsec resolution */
#define DEM_FILE_SIZE_LON_DEG	40      /* degrees of longitude per file */
#define DEM_FILE_SIZE_LAT_DEG	50      /* degrees of latitude per file */
#define DEM_FILE_N_COLUMNS	(DEM_FILE_SIZE_LON_DEG * DEM_CELL_PER_DEG)
#define DEM_FILE_N_ROWS		(DEM_FILE_SIZE_LAT_DEG * DEM_CELL_PER_DEG)
#define DEM_FILE_SIZE_ENTRIES	(DEM_FILE_N_COLUMNS * DEM_FILE_N_ROWS)
#define DEM_FILE_SIZE_BYTES	(DEM_FILE_SIZE_ENTRIES * DEM_ENTRY_SIZE)

#define DEM_N_FILES_LON		((LON_MAX_DEG - LON_MIN_DEG) / DEM_FILE_SIZE_LON_DEG)
#define DEM_N_FILES_LAT		((LAT_MAX_DEG - LAT_MIN_DEG) / DEM_FILE_SIZE_LAT_DEG)


/*
 * Conversion from coordinates to DEM file name, and index within the file.
 *
 * Coordinate systems:
 * - file indices : origin at {LON,LAT}_MIN_DEG, unit is DEM_FILE_SIZE_{LON,LAT}_DEG
 * - DEM cell indices : origin at {LON,LAT}_MIN_DEG, unit is 1 / DEM_CELL_PER_DEG
 *
 * In all cases, north / east is positive.
 */

#define DEM_FILENAME_SIZE	11

/*
 * lon_idx / lat_idx are indices of columns / rows of DEM files.
 * Its unit is DEM_FILE_SIZE_{LON,LAT}_DEG, with 0 corresponding to {LON,LAT}_MIN_DEG.
 */
char *dem_file_idx_to_name(size_t file_lon_idx, size_t file_lat_idx, char buffer[DEM_FILENAME_SIZE+1])
{
	/* File is identified by its north-west corner */
	int lon = LON_MIN_DEG + file_lon_idx * DEM_FILE_SIZE_LON_DEG;
	int lat = LAT_MIN_DEG + (file_lat_idx + 1) * DEM_FILE_SIZE_LAT_DEG;
	int lon_char = lon < 0 ? 'W' : 'E';
	int lat_char = lat < 0 ? 'S' : 'N';
	if (lon < 0)
		lon = -lon;
	if (lat < 0)
		lat = -lat;

	int size = snprintf(buffer, DEM_FILENAME_SIZE+1, "%c%.3d%c%.2d.DEM", lon_char, lon, lat_char, lat);
	assert(size == DEM_FILENAME_SIZE);
	return buffer;
}


static inline size_t lon_idx_cell2file(size_t cell_lon_idx)
{
	return cell_lon_idx / DEM_FILE_N_COLUMNS;
}

static inline size_t lat_idx_cell2file(size_t cell_lat_idx)
{
	return cell_lat_idx / DEM_FILE_N_ROWS;
}

static inline size_t cell_idx_to_file_offset(size_t cell_lon_idx, size_t cell_lat_idx)
{
	cell_lon_idx %= DEM_FILE_N_COLUMNS;
	cell_lat_idx %= DEM_FILE_N_ROWS;
	/* GTOPO30 starts with northmost row */
	cell_lat_idx = DEM_FILE_N_ROWS - cell_lat_idx - 1;
	/* row major order */
	return cell_lat_idx * DEM_FILE_N_COLUMNS + cell_lon_idx;
}


/*
 * Load GTOPO30 file to buffer.
 *
 * 'data' must either a buffer of size at least DEM_FILE_SIZE_BYTES.
 * Return a pointer to 'data', or NULL in case of failure.
 */
dem_elev_t *load_dem_file(dem_elev_t *data, const char *filename)
{
	fprintf(stderr, "Loading %s\n", filename);

	FILE *file = fopen(filename, "rb");
	ssize_t size = 0;

	if (!file)
		goto perror;

	if (fseek(file, 0, SEEK_END) < 0 || (size = ftell(file)) < 0)
		goto perror;

	if (size != DEM_FILE_SIZE_BYTES) {
		fprintf(stderr, "load_dem_file: unexpected file size for %s, expected %d, got %ld\n",
			filename, DEM_FILE_SIZE_BYTES, size);
		goto exit;
	}

	if (fseek(file, 0, SEEK_SET) < 0)
		goto perror;

	size = fread(data, 1, DEM_FILE_SIZE_BYTES, file);
	if (size < DEM_FILE_SIZE_BYTES) {
		if (ferror(file)) {
			goto perror;
		} else {
			fprintf(stderr, "load_dem_file: unexpected EOF while reading %s\n", filename);
			goto exit;
		}
	}

	fclose(file);
	file = NULL;

	for (size_t i=0; i<DEM_FILE_SIZE_ENTRIES; i++) {
		data[i] = decode_dem_elev(data[i]);
	}

	return data;

perror:
	perror("load_dem_file");
exit:
	if (file) fclose(file);
	return NULL;
}


/* Global table of DEM files data */
struct dem_file_data {
	dem_elev_t *data;		/* file content buffer */
	int last_access;	/* last access number, for caching */
};

struct dem_file_data dem_data[DEM_N_FILES_LON][DEM_N_FILES_LAT] = {0};
int access = 0;			/* access number */

/*
 * Get data buffer corresponding to a DEM file
 *
 * Retreive the cached file content, or load it if missing.
 * Arguments: indices of the desired file.
 * Return a pointer to a buffer of DEM_FILE_SIZE_ENTRIES dem_elev_t with the file content.
 * Return NULL in case of error.
 */
dem_elev_t *get_dem_file_data(size_t file_lon_idx, size_t file_lat_idx)
{
	struct dem_file_data *desc = &dem_data[file_lon_idx][file_lat_idx];
	if (desc->data)
		/* present */
		goto success;

	desc->data = calloc(DEM_FILE_SIZE_ENTRIES, sizeof(desc->data[0]));
	if (!desc->data) {
		/* TODO: try reclaiming memory */
		perror("get_dem_file_data");
		return NULL;
	}

	char filename[DEM_FILENAME_SIZE+1];
	dem_file_idx_to_name(file_lon_idx, file_lat_idx, filename);

	if (!load_dem_file(desc->data, filename)) {
		/* deallocate so that this buffer doesn't get used as if it were valid */
		free(desc->data);
		desc->data = NULL;
		return NULL;
	}

success:
	desc->last_access = ++access;
	return desc->data;
}

/*
 * Get elevation of a given DEM cell.
 *
 * Return DEM_INVALID in case of error.
 */
dem_elev_t get_dem_cell(size_t cell_lon_idx, size_t cell_lat_idx)
{
	size_t file_lon_idx = lon_idx_cell2file(cell_lon_idx);
	size_t file_lat_idx = lat_idx_cell2file(cell_lat_idx);
	size_t offset = cell_idx_to_file_offset(cell_lon_idx, cell_lat_idx);

	dem_elev_t *data = get_dem_file_data(file_lon_idx, file_lat_idx);
	if (!data)
		return DEM_INVALID;
	else
		return data[offset];
}

void free_dem_data(void)
{
	for (size_t i=0; i<DEM_N_FILES_LON; i++) {
		for (size_t j=0; j<DEM_N_FILES_LAT; j++) {
			free(dem_data[i][j].data);
			dem_data[i][j].data = NULL;
		}
	}
}



/*
 * Output file
 */
#define OUT_CELL_PER_DEG	10      /* 6 arcmin resolution */

/* Ratio (side of output cell / side of DEM cell) */
static_assert(DEM_CELL_PER_DEG % OUT_CELL_PER_DEG == 0);
#define DEM_CELL_PER_OUT_CELL_SIDE	(DEM_CELL_PER_DEG / OUT_CELL_PER_DEG)
/* Total number of DEM cells contained in an output cell */
#define DEM_CELL_PER_OUT_CELL		(DEM_CELL_PER_OUT_CELL_SIDE * DEM_CELL_PER_OUT_CELL_SIDE)

#define OUT_N_CELL_LON		((LON_MAX_DEG - LON_MIN_DEG) * OUT_CELL_PER_DEG)
#define OUT_N_CELL_LAT		((LAT_MAX_DEG - LAT_MIN_DEG) * OUT_CELL_PER_DEG)
#define OUT_N_CELL		(OUT_N_CELL_LON * OUT_N_CELL_LAT)

#define OUT_FILE		"ja37.elev"

typedef uint8_t out_elev_t;

/*
 * Encode elevations as single bytes, with vertical resolution of 64m.
 *
 * Encoding:
 *  - divide by 64, round to closest
 *  - if value is negative, wrap to positive modulo 256
 * In practice, positive values do not exceed 191, and negative ones
 * do not exceed -64, so [-64,-1] is wrapped around to [192,255].
 *
 * In this implementation, ties are rounded up. It doesn't really matter.
 */
out_elev_t encode_output_elev(int elev)
{
	/* Divide by 32, rounds towards negative infinity. */
	elev >>= 5;
	/* Divide by 2, rounds towards positive infinity. */
	elev += 1;
	elev >>= 1;

	return (out_elev_t) elev;
}

/*
 * Load elevation of all DEM cells contained in the given output cell to buffer.
 *
 * 'cell_{lon,lat}_idx' are the coordinates of the desired output cell.
 * 'buffer' must have size DEM_CELL_PER_OUT_CELL.
 * Return 'buffer', or NULL in case of failure.
 */
dem_elev_t *load_dem_data_for_out_cell(
	size_t cell_lon_idx, size_t cell_lat_idx,
	dem_elev_t buffer[DEM_CELL_PER_OUT_CELL])
{
	/* south-west most DEM cell contained in this output cell */
	size_t dem_lon_idx_start = cell_lon_idx * DEM_CELL_PER_OUT_CELL_SIDE;
	size_t dem_lat_idx_start = cell_lat_idx * DEM_CELL_PER_OUT_CELL_SIDE;
	size_t dem_lon_idx_end = dem_lon_idx_start + DEM_CELL_PER_OUT_CELL_SIDE;
	size_t dem_lat_idx_end = dem_lat_idx_start + DEM_CELL_PER_OUT_CELL_SIDE;

	size_t buffer_idx = 0;

	for (size_t j = dem_lat_idx_start; j < dem_lat_idx_end; j++) {
		for (size_t i = dem_lon_idx_start; i < dem_lon_idx_end; i++) {
			dem_elev_t elev = get_dem_cell(i, j);
			if (DEM_IS_INVALID(elev))
				return NULL;
			buffer[buffer_idx++] = elev;
		}
	}

	return buffer;
}



/* CORE LOGIC HERE */

int cmp(const void *x, const void *y)
{
	int _x = *(dem_elev_t*)x;
	int _y = *(dem_elev_t*)y;

	if (_x < _y) return 1;
	else if (_x > _y) return -1;
	else return 0;
}

static inline int max(int x, int y)
{
	return x > y ? x : y;
}

/*
 * Compute output cell elevation from a number of input samples.
 *
 * JA 37 manual gives little detail about how this is done. Simply:
 *
 * > Each square has been allotted its own terrain level,
 * > which is based on average elevation and maximum elevation.
 *
 * 
 */
int compute_out_cell_elev(dem_elev_t *buffer, size_t buffer_size)
{
	if (buffer_size == 0)
		return 0;

	long sum = 0;
	for (size_t i=0; i<buffer_size; i++)
		sum += buffer[i];
	int avg = sum / buffer_size;

	qsort(buffer, buffer_size, sizeof(*buffer), cmp);
	int quantile = buffer[buffer_size / 20];

	return max(avg, quantile);
}



int main()
{
	dem_elev_t *buffer = NULL;
	FILE *output = NULL;
	int ret = EXIT_SUCCESS;

	buffer = calloc(DEM_CELL_PER_OUT_CELL, sizeof(*buffer));
	if (!buffer)
		goto perror;

	output = fopen(OUT_FILE, "wb");
	if (!output)
		goto perror;

	for (size_t j=0; j<OUT_N_CELL_LAT; j++) {
		for (size_t i=0; i<OUT_N_CELL_LON; i++) {
			if (!load_dem_data_for_out_cell(i, j, buffer))
				goto error;

			int elev = compute_out_cell_elev(buffer, DEM_CELL_PER_OUT_CELL);
#ifdef DEBUG
			fprintf(stderr, "lon: %6.1f lat: %5.1f elev: %d\n",
				LON_MIN_DEG + i / (float) OUT_CELL_PER_DEG,
				LAT_MIN_DEG + j / (float) OUT_CELL_PER_DEG,
				elev);
#endif

			out_elev_t out = encode_output_elev(elev);

			if (fwrite(&out, sizeof(out), 1, output) != 1)
				goto perror;
		}
	}

	goto exit;

perror:
	perror("main");
error:
	ret = EXIT_FAILURE;
exit:
	free_dem_data();
	free(buffer);
	if (output) {
		fclose(output);
		output = NULL;
	}
	return ret;
}
