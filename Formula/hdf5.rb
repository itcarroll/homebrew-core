class Hdf5 < Formula
  desc "File format designed to store large amounts of data"
  homepage "https://www.hdfgroup.org/HDF5"
  url "https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.12/hdf5-1.12.2/src/CMake-hdf5-1.12.2.tar.gz"
  sha256 "04621dd1b96426f7f7883d508657fb1ee579ddd22f4c38ababfd8a408abd6525"
  license "BSD-3-Clause"
  revision 3
  version_scheme 1

  # This regex isn't matching filenames within href attributes (as we normally
  # do on HTML pages) because this page uses JavaScript to handle the download
  # buttons and the HTML doesn't contain the related URLs.
  livecheck do
    url "https://www.hdfgroup.org/downloads/hdf5/source-code/"
    regex(/>\s*hdf5[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  depends_on "cmake" => :build
  depends_on "gcc" # for gfortran
  depends_on "libaec"

  uses_from_macos "zlib" #FIXME need to implement with cmake

  conflicts_with "hdf5-mpi", because: "hdf5-mpi is a variant of hdf5, one can only use one or the other"

  def install
    # ENV.deparallelize  # if your formula fails when building in parallel
    # Remove unrecognized options if warned by configure
    # https://rubydoc.brew.sh/Formula.html#std_configure_args-instance_method

    # FIXME
    #   netcdf and gdal cannot find hdf5 after install, perhaps because the
    #   installed path is /usr/local/Cellar/hdf5/1.13.3/HDF_Group/HDF5/1.13.3/.
    #   the INSTALLDIR replacement below appears to have no effect.
    inreplace "HDF5config.cmake",
              "INSTALLDIR \"${CTEST_SCRIPT_DIRECTORY}/HDF_Group/HDF5/${CTEST_SOURCE_VERSION}\"",
              "INSTALLDIR \"${CTEST_SCRIPT_DIRECTORY}\""
    # FIXME
    #  Homebrew advises passing options as command line args, but this may not
    #  be possible while using the `ctest -S` pattern in `./build-unix.sh`
    inreplace "HDF5options.cmake",
              "-DHDF5_BUILD_FORTRAN:BOOL=OFF",
              "-DHDF5_BUILD_FORTRAN:BOOL=ON"
    system "./build-unix.sh"
    system "./HDF5-1.13.3-Darwin.sh --skip-license --exclude-subdir --prefix=#{prefix}"
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <stdio.h>
      #include "hdf5.h"
      int main()
      {
        printf("%d.%d.%d\\n", H5_VERS_MAJOR, H5_VERS_MINOR, H5_VERS_RELEASE);
        return 0;
      }
    EOS
    system "#{bin}/h5cc", "test.c"
    assert_equal version.to_s, shell_output("./a.out").chomp

    (testpath/"test.f90").write <<~EOS
      use hdf5
      integer(hid_t) :: f, dspace, dset
      integer(hsize_t), dimension(2) :: dims = [2, 2]
      integer :: error = 0, major, minor, rel

      call h5open_f (error)
      if (error /= 0) call abort
      call h5fcreate_f ("test.h5", H5F_ACC_TRUNC_F, f, error)
      if (error /= 0) call abort
      call h5screate_simple_f (2, dims, dspace, error)
      if (error /= 0) call abort
      call h5dcreate_f (f, "data", H5T_NATIVE_INTEGER, dspace, dset, error)
      if (error /= 0) call abort
      call h5dclose_f (dset, error)
      if (error /= 0) call abort
      call h5sclose_f (dspace, error)
      if (error /= 0) call abort
      call h5fclose_f (f, error)
      if (error /= 0) call abort
      call h5close_f (error)
      if (error /= 0) call abort
      CALL h5get_libversion_f (major, minor, rel, error)
      if (error /= 0) call abort
      write (*,"(I0,'.',I0,'.',I0)") major, minor, rel
      end
    EOS
    system "#{bin}/h5fc", "test.f90"
    assert_equal version.to_s, shell_output("./a.out").chomp
  end
end
