//
//  PublicTimelineViewModel.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/1/27.
//

import AlamofireImage
import Combine
import CoreData
import CoreDataStack
import GameplayKit
import MastodonSDK
import os.log
import UIKit

class PublicTimelineViewModel: NSObject {
    var disposeBag = Set<AnyCancellable>()
    
    // input
    let context: AppContext
    let fetchedResultsController: NSFetchedResultsController<Toot>
    
    let isFetchingLatestTimeline = CurrentValueSubject<Bool, Never>(false)
    
    // middle loader
    let loadMiddleSateMachineList = CurrentValueSubject<[String: GKStateMachine], Never>([:])
    
    weak var tableView: UITableView?
    
    weak var contentOffsetAdjustableTimelineViewControllerDelegate: ContentOffsetAdjustableTimelineViewControllerDelegate?
    
    //
    var tootIDsWhichHasGap = [String]()
    // output
    var diffableDataSource: UITableViewDiffableDataSource<TimelineSection, Item>?

    lazy var stateMachine: GKStateMachine = {
        let stateMachine = GKStateMachine(states: [
            State.Initial(viewModel: self),
            State.Loading(viewModel: self),
            State.Fail(viewModel: self),
            State.Idle(viewModel: self),
            State.LoadingMore(viewModel: self),
        ])
        stateMachine.enter(State.Initial.self)
        return stateMachine
    }()
    
    let tootIDs = CurrentValueSubject<[String], Never>([])
    let items = CurrentValueSubject<[Item], Never>([])
    var cellFrameCache = NSCache<NSNumber, NSValue>()
    
    init(context: AppContext) {
        self.context = context
        self.fetchedResultsController = {
            let fetchRequest = Toot.sortedFetchRequest
            fetchRequest.predicate = Toot.predicate(domain: "", ids: [])
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.fetchBatchSize = 20
            let controller = NSFetchedResultsController(
                fetchRequest: fetchRequest,
                managedObjectContext: context.managedObjectContext,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            
            return controller
        }()
        super.init()
        
        fetchedResultsController.delegate = self
        
        items
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self = self else { return }
                guard let diffableDataSource = self.diffableDataSource else { return }
                guard let navigationBar = self.contentOffsetAdjustableTimelineViewControllerDelegate?.navigationBar() else { return }
                guard let tableView = self.tableView else { return }
                let oldSnapshot = diffableDataSource.snapshot()
                os_log("%{public}s[%{public}ld], %{public}s: items did change", (#file as NSString).lastPathComponent, #line, #function)

                var snapshot = NSDiffableDataSourceSnapshot<TimelineSection, Item>()
                snapshot.appendSections([.main])
                snapshot.appendItems(items)
                if let currentState = self.stateMachine.currentState {
                    switch currentState {
                    case is State.Idle, is State.LoadingMore, is State.Fail:
                        snapshot.appendItems([.bottomLoader], toSection: .main)
                    default:
                        break
                    }
                }

                DispatchQueue.main.async {

                    guard let difference = self.calculateReloadSnapshotDifference(navigationBar: navigationBar, tableView: tableView, oldSnapshot: oldSnapshot, newSnapshot: snapshot) else {
                        diffableDataSource.apply(snapshot)
                        self.isFetchingLatestTimeline.value = false
                        return
                    }
                    
                    diffableDataSource.apply(snapshot, animatingDifferences: false) {
                        tableView.scrollToRow(at: difference.targetIndexPath, at: .top, animated: false)
                        tableView.contentOffset.y = tableView.contentOffset.y - difference.offset
                        self.isFetchingLatestTimeline.value = false
                    }
                }
            }
            .store(in: &disposeBag)
        
        tootIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ids in
                guard let self = self else { return }
                let domain = self.context.authenticationService.activeMastodonAuthenticationBox.value?.domain ?? ""
                self.fetchedResultsController.fetchRequest.predicate = Toot.predicate(domain: domain, ids: ids)
                do {
                    try self.fetchedResultsController.performFetch()
                } catch {
                    assertionFailure(error.localizedDescription)
                }
            }
            .store(in: &disposeBag)
    }
    
    deinit {
        os_log("%{public}s[%{public}ld], %{public}s", (#file as NSString).lastPathComponent, #line, #function)
    }
    
    private struct Difference<T> {
        let item: T
        let sourceIndexPath: IndexPath
        let targetIndexPath: IndexPath
        let offset: CGFloat
    }
    
    private func calculateReloadSnapshotDifference<T: Hashable>(
        navigationBar: UINavigationBar,
        tableView: UITableView,
        oldSnapshot: NSDiffableDataSourceSnapshot<TimelineSection, T>,
        newSnapshot: NSDiffableDataSourceSnapshot<TimelineSection, T>
    ) -> Difference<T>? {
        guard oldSnapshot.numberOfItems != 0 else { return nil }
        
        // old snapshot not empty. set source index path to first item if not match
        let sourceIndexPath = UIViewController.topVisibleTableViewCellIndexPath(in: tableView, navigationBar: navigationBar) ?? IndexPath(row: 0, section: 0)
        
        guard sourceIndexPath.row < oldSnapshot.itemIdentifiers(inSection: .main).count else { return nil }
        
        let timelineItem = oldSnapshot.itemIdentifiers(inSection: .main)[sourceIndexPath.row]
        guard let itemIndex = newSnapshot.itemIdentifiers(inSection: .main).firstIndex(of: timelineItem) else { return nil }
        let targetIndexPath = IndexPath(row: itemIndex, section: 0)
        
        let offset = UIViewController.tableViewCellOriginOffsetToWindowTop(in: tableView, at: sourceIndexPath, navigationBar: navigationBar)
        return Difference(
            item: timelineItem,
            sourceIndexPath: sourceIndexPath,
            targetIndexPath: targetIndexPath,
            offset: offset
        )
    }
}
