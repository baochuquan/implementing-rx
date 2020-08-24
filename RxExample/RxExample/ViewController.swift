import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController {
    var bag = DisposeBag()


    override func viewDidLoad() {
        super.viewDidLoad()
        test01()
    }
    
    func test01() {
        let observable: Observable<Int> = Observable.create { (observer) -> Disposable in
            print("send 0")
            observer.onNext(0)
            print("send 1")
            observer.onNext(1)
            print("send 2")
            observer.onNext(2)
            print("send 3")
            observer.onNext(3)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                print("send completed")
                observer.onCompleted()
            }
            return Disposables.create()
        }

        observable.map { $0 + 2}.filter { $0 > 3 }.subscribe { (event) in
            switch (event) {
            case .next(let value):
                print("receive \(value)")
            case .error(let error):
                print("receive \(error)")
            case .completed:
                print("receive completed")
            }
        }.disposed(by: bag)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.bag = DisposeBag()
        }
    }
}
