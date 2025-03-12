import Foundation

import enum Accelerate.vDSP

enum FloatMeanErr: Error {
  case mmapError
  case munmapError
}

func mmap_read(size: Int, fd: Int32) -> Result<UnsafeMutableRawPointer, Error> {
  let oraw: UnsafeMutableRawPointer? = Foundation.mmap(
    nil,
    size,
    Foundation.PROT_READ,
    Foundation.MAP_SHARED,
    fd,
    0
  )
  guard let raw = oraw else {
    return .failure(FloatMeanErr.mmapError)
  }
  return .success(raw)
}

func mmap_close(addr: UnsafeMutableRawPointer, size: Int) -> Result<(), Error> {
  guard 0 == Foundation.munmap(addr, size) else {
    return .failure(FloatMeanErr.munmapError)
  }
  return .success(())
}

class MmapRead {
  let size: Int
  let addr: UnsafeMutableRawPointer

  init?(size: Int, fd: Int32) {
    self.size = size

    let res: Result<UnsafeMutableRawPointer, _> = mmap_read(
      size: size,
      fd: fd
    )

    switch res {
    case .success(let addr):
      self.addr = addr
    case .failure:
      return nil
    }
  }

  public func toRawPointer() -> UnsafeRawPointer { UnsafeRawPointer(self.addr) }

  public func toPointerFloat() -> UnsafePointer<Float32> {
    self.toRawPointer().assumingMemoryBound(to: Float32.self)
  }

  public func toBufferFloat() -> UnsafeBufferPointer<Float32> {
    UnsafeBufferPointer(start: self.toPointerFloat(), count: self.size >> 2)
  }

  deinit {
    let res: Result<_, Error> = mmap_close(addr: self.addr, size: self.size)
    switch res {
    case .success: return
    case .failure(let err):
      print("error while munmap: \( err )")
    }
  }
}

@main
struct FloatMeanMmap {
  static func main() {
    let ofilename: String? = Foundation.ProcessInfo
      .processInfo
      .environment["ENV_FLOAT_DAT_NAME"]

    guard let filename = ofilename else {
      print("ENV_FLOAT_DAT_NAME missing")
      return
    }

    let omaxFileSizeStr: String? = Foundation.ProcessInfo
      .processInfo
      .environment["ENV_MAX_FILE_SIZE"]

    let omaxFileSize: UInt32? = UInt32(omaxFileSizeStr ?? "1048576")
    let maxFileSize: UInt32 = omaxFileSize ?? 1_048_576

    let ofile: FileHandle? = FileHandle(forReadingAtPath: filename)
    guard let file = ofile else {
      print("unable to open: \( filename )")
      return
    }

    let fd: Int32 = file.fileDescriptor
    var st: Foundation.stat = Foundation.stat.init()
    guard 0 == Foundation.fstat(fd, &st) else {
      print("unable to get file stat")
      return
    }

    let fileSize: Int64 = st.st_size
    guard fileSize <= Int64(maxFileSize) else {
      print(
        "file size limit error(size=\( fileSize )): make ENV_MAX_FILE_SIZE bigger."
      )
      return
    }

    guard let mapd = MmapRead(size: Int(fileSize), fd: fd) else {
      print("unable to mmap")
      return
    }

    let buf: UnsafeBufferPointer<Float32> = mapd.toBufferFloat()
    let avg: Float = vDSP.mean(buf)

    print("\( avg )")
  }
}
