import Foundation

// MARK: - Event

enum Event<Element> {
    case next(Element)
    case error(Error)
    case completed
}

// MARK: - Observer

protocol ObserverType {
    associatedtype Element
    
    // 监听事件
    func on(event: Event<Element>)
}

class Observer<Element>: ObserverType {
    
    // 订阅者如何处理事件的闭包
    private let _handler: (Event<Element>) -> Void
    
    init(_ handler: @escaping (Event<Element>) -> Void) {
        _handler = handler
    }
    
    // 实现 监听事件 的协议，内部处理事件
    func on(event: Event<Element>) {
        // 处理事件
        _handler(event)
    }
}

// MARK: - Observable

protocol ObservableType {
    associatedtype Element
    
    // 订阅操作
    func subscribe<O: ObserverType>(observer: O) -> Disposable where O.Element == Element
}

class Observable<Element>: ObservableType {
    // 定义 发布事件 的闭包
    private let _eventGenerator: (Observer<Element>) -> Disposable
    
    init(_ eventGenerator: @escaping (Observer<Element>) -> Disposable) {
        _eventGenerator = eventGenerator
    }
    
    // 实现 订阅操作 的协议，内部生成事件
    func subscribe<O: ObserverType>(observer: O) -> Disposable where O.Element == Element {
        let composite = CompositeDisposable()
        // 通过一个中间 Observer 接收原始事件
        // 根据 CompositionDisposable 的状态决定是否传递给原始 Observer
        let disposable = _eventGenerator(Observer { (event) in
            guard !composite.isDisposed else { return }
            // 事件传递给原始 observer
            observer.on(event: event)
            // 通过 composite 管理 error、completed 时，自动取消订阅
            switch event {
            case .error(_), .completed:
                composite.dispose()
            default:
                break
            }
        })
        // 将 _eventGenerator 返回的 AnonymousDisposable 加入至 CompositeDisposable 中进行管理
        composite.add(disposable: disposable)
        return composite
    }
}

// MARK: - Disposable

protocol Disposable {
    // 取消订阅
    func dispose()
}

final class AnonymousDisposable: Disposable {
    // AnonymousDisposable 封装了 取消订阅时附带操作 的闭包
    private let _disposeHandler: () -> Void
    
    init(_ disposeClosure: @escaping () -> Void) {
        _disposeHandler = disposeClosure
    }
    
    func dispose() {
        _disposeHandler()
    }
}

class CompositeDisposable: Disposable {
    // 可用于管理一组 Disposable 的 CompositeDisposable

    // 判断是否已销毁的标志位
    private(set) var isDisposed: Bool = false
    // 管理一组 Disposable
    private var disposables: [Disposable] = []
    
    init() {}
    
    func add(disposable: Disposable) {
        if isDisposed {
            disposable.dispose()
            return
        }
        disposables.append(disposable)
    }
    
    func dispose() {
        guard !isDisposed else { return }
        // 销毁所有 disposable，并设置标志位
        disposables.forEach {
            $0.dispose()
        }
        isDisposed = true
    }
}

// MARK: - Test

let observable = Observable<Int> { (observer) -> Disposable in
    print("send 0")
    observer.on(event: .next(0))    // observer.on(event: .next(0).map({ $0 * 2 }))
    print("send 1")
    observer.on(event: .next(1))
    print("send 2")
    observer.on(event: .next(2))
    print("send 3")
    observer.on(event: .next(3))
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        print("send completed")
        observer.on(event: .completed)
    }
    return AnonymousDisposable {
        print("dispose")
    }
}

let observer = Observer<Int> { (event) in
    switch event {
    case .next(let value):
        print("recive \(value)")
    case .error(let error):
        print("recive \(error)")
    case .completed:
        print("recive completed")
    }
}

let disposable = observable.subscribe(observer: observer)

DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    disposable.dispose()
}
