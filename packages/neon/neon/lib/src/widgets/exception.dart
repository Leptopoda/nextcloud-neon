part of '../../neon.dart';

class NeonException extends StatelessWidget {
  const NeonException(
    this.exception, {
    required this.onRetry,
    this.onlyIcon = false,
    this.iconSize,
    this.color,
    super.key,
  });

  final dynamic exception;
  final Function() onRetry;
  final bool onlyIcon;
  final double? iconSize;
  final Color? color;

  static void showSnackbar(final BuildContext context, final dynamic exception) {
    final details = _getExceptionDetails(context, exception);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(details.text),
        action: details.isUnauthorized
            ? SnackBarAction(
                label: AppLocalizations.of(context).loginAgain,
                onPressed: () async => _openLoginPage(context),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(final BuildContext context) => exception == null
      ? Container()
      : Container(
          padding: !onlyIcon ? const EdgeInsets.all(5) : null,
          child: Builder(
            builder: (final context) {
              final details = _getExceptionDetails(context, exception);

              final errorIcon = Icon(
                Icons.error_outline,
                size: iconSize ?? 30,
                color: color ?? Colors.red,
              );

              if (onlyIcon) {
                return Semantics(
                  tooltip: details.text,
                  child: IconButton(
                    icon: errorIcon,
                    padding: EdgeInsets.zero,
                    visualDensity: const VisualDensity(
                      horizontal: VisualDensity.minimumDensity,
                      vertical: VisualDensity.minimumDensity,
                    ),
                    tooltip: details.isUnauthorized
                        ? AppLocalizations.of(context).loginAgain
                        : AppLocalizations.of(context).actionRetry,
                    onPressed: () async {
                      if (details.isUnauthorized) {
                        _openLoginPage(context);
                      } else {
                        onRetry();
                      }
                    },
                  ),
                );
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      errorIcon,
                      const SizedBox(
                        width: 10,
                      ),
                      Flexible(
                        child: Text(
                          details.text,
                          style: TextStyle(
                            color: color ?? Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (details.isUnauthorized) ...[
                    ElevatedButton(
                      onPressed: () async => _openLoginPage(context),
                      child: Text(AppLocalizations.of(context).loginAgain),
                    ),
                  ] else ...[
                    ElevatedButton(
                      onPressed: onRetry,
                      child: Text(AppLocalizations.of(context).actionRetry),
                    ),
                  ],
                ],
              );
            },
          ),
        );

  static _ExceptionDetails _getExceptionDetails(final BuildContext context, final dynamic exception) {
    if (exception is String) {
      return _ExceptionDetails(
        text: exception,
      );
    }

    if (exception is MissingPermissionException) {
      return _ExceptionDetails(
        text: AppLocalizations.of(context).errorMissingPermission(exception.permission.toString().split('.')[1]),
      );
    }

    if (exception is UnableToOpenFileException) {
      return _ExceptionDetails(
        text: AppLocalizations.of(context).errorUnableToOpenFile,
      );
    }

    if (exception is NextcloudApiException) {
      if (exception.statusCode == 401) {
        return _ExceptionDetails(
          text: AppLocalizations.of(context).errorCredentialsForAccountNoLongerMatch,
          isUnauthorized: true,
        );
      }

      if (exception.statusCode >= 500 && exception.statusCode <= 599) {
        return _ExceptionDetails(
          text: AppLocalizations.of(context).errorServerHadAProblemProcessingYourRequest,
        );
      }
    }

    if (exception is SocketException) {
      return _ExceptionDetails(
        text: exception.address != null
            ? AppLocalizations.of(context).errorUnableToReachServerAt(exception.address!.host)
            : AppLocalizations.of(context).errorUnableToReachServer,
      );
    }

    if (exception is ClientException) {
      return _ExceptionDetails(
        text: exception.uri != null
            ? AppLocalizations.of(context).errorUnableToReachServerAt(exception.uri!.host)
            : AppLocalizations.of(context).errorUnableToReachServer,
      );
    }

    if (exception is HttpException) {
      return _ExceptionDetails(
        text: exception.uri != null
            ? AppLocalizations.of(context).errorUnableToReachServerAt(exception.uri!.host)
            : AppLocalizations.of(context).errorUnableToReachServer,
      );
    }

    if (exception is TimeoutException) {
      return _ExceptionDetails(
        text: AppLocalizations.of(context).errorConnectionTimedOut,
      );
    }

    return _ExceptionDetails(
      text: AppLocalizations.of(context).errorSomethingWentWrongTryAgainLater,
    );
  }

  static void _openLoginPage(final BuildContext context) {
    LoginRoute(
      server: Provider.of<AccountsBloc>(context, listen: false).activeAccount.value!.serverURL,
    ).go(context);
  }
}

class _ExceptionDetails {
  _ExceptionDetails({
    required this.text,
    this.isUnauthorized = false,
  });

  final String text;
  final bool isUnauthorized;
}
