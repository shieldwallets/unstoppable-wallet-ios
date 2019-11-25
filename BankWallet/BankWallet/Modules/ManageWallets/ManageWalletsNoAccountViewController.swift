import UIKit
import ActionSheet

class ManageWalletsNoAccountViewController: WalletActionSheetController {

    init(coin: Coin, predefinedAccountType: PredefinedAccountType, onSelectNew: @escaping () -> (), onSelectRestore: @escaping () -> ()) {
        super.init(withModel: BaseAlertModel(), actionSheetThemeConfig: AppTheme.actionSheetConfig)

        let titleItem = AlertTitleItem(
                title: "manage_coins.add_coin.title".localized(coin.title),
                subtitle: predefinedAccountType.title,
                icon: UIImage(coin: coin),
                iconTintColor: AppTheme.coinIconColor,
                tag: 0,
                onClose: { [weak self] in
                    self?.dismiss(byFade: false)
                }
        )

        let textItem = AlertTextItem(text: "manage_coins.add_coin.text".localized(coin.title, coin.code, predefinedAccountType.coinCodes, predefinedAccountType.title), tag: 1)

        model.addItemView(titleItem)
        model.addItemView(textItem)

        let newItem = AlertButtonItem(
                tag: 2,
                title: "manage_coins.add_coin.create".localized,
                createButton: { .appYellow },
                insets: UIEdgeInsets(top: ButtonTheme.verticalMargin, left: ButtonTheme.margin, bottom: ButtonTheme.insideMargin, right: ButtonTheme.margin)
        ) { [weak self] in
            self?.dismiss(animated: true) {
                onSelectNew()
            }
        }
        newItem.isEnabled = true

        model.addItemView(newItem)

        let restoreItem = AlertButtonItem(
                tag: 3,
                title: "manage_coins.add_coin.restore".localized,
                createButton: { .appGray },
                insets: UIEdgeInsets(top: ButtonTheme.insideMargin, left: ButtonTheme.margin, bottom: ButtonTheme.verticalMargin, right: ButtonTheme.margin)
        ) { [weak self] in
            self?.dismiss(animated: true) {
                onSelectRestore()
            }
        }
        restoreItem.isEnabled = true

        model.addItemView(restoreItem)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        backgroundColor = AppTheme.actionSheetBackgroundColor
        contentBackgroundColor = .white
    }

}
