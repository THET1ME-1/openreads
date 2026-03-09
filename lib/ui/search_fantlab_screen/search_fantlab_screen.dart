import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:openreads/core/constants/enums/enums.dart';
import 'package:openreads/core/themes/app_theme.dart';
import 'package:openreads/generated/locale_keys.g.dart';
import 'package:openreads/logic/cubit/default_book_status_cubit.dart';
import 'package:openreads/logic/cubit/default_book_tags_cubit.dart';
import 'package:openreads/logic/cubit/edit_book_cubit.dart';
import 'package:openreads/model/fl_search_result.dart';
import 'package:openreads/model/reading.dart';
import 'package:openreads/model/book.dart';
import 'package:openreads/resources/fantlab_service.dart';
import 'package:openreads/ui/add_book_screen/add_book_screen.dart';
import 'package:openreads/ui/add_book_screen/widgets/widgets.dart';
import 'package:openreads/ui/common/keyboard_dismissable.dart';
import 'package:openreads/ui/search_fantlab_screen/widgets/widgets.dart';

class SearchFantLabScreen extends StatefulWidget {
  const SearchFantLabScreen({
    super.key,
    required this.status,
  });

  final BookStatus status;

  @override
  State<SearchFantLabScreen> createState() => _SearchFantLabScreenState();
}

class _SearchFantLabScreenState extends State<SearchFantLabScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  String? _searchTerm;
  int? numberOfResults;
  int searchTimestamp = 0;
  bool searchActivated = false;

  late final _pagingController = PagingController<int, FLSearchResultWork>(
    fetchPage: (pageKey) => _fetchPage(pageKey),
    getNextPageKey: (state) =>
        state.lastPageIsEmpty ? null : state.nextIntPageKey,
  );

  Future<List<FLSearchResultWork>> _fetchPage(int pageKey) async {
    final searchTimestampSaved = DateTime.now().millisecondsSinceEpoch;
    searchTimestamp = searchTimestampSaved;

    try {
      if (_searchTerm == null || _searchTerm!.isEmpty) return [];

      final results = await FantLabService().searchWorks(
        query: _searchTerm!,
        page: pageKey,
      );

      // Cancel if a new search was started
      if (searchTimestamp != searchTimestampSaved) return [];

      // Filter to only book-like types (exclude articles, reviews, poems)
      final filtered = results.where((r) => r.isBookType).toList();

      return filtered;
    } catch (error) {
      return [];
    }
  }

  void _startNewSearch() {
    if (_searchController.text.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      searchActivated = true;
    });

    _searchTerm = _searchController.text;
    _pagingController.refresh();
  }

  void _onAddBookPressed(FLSearchResultWork item) async {
    // Fetch detailed work info (for description)
    final work = await FantLabService().getWork(item.workId);

    if (!mounted) return;

    final defaultBookFormat = context.read<DefaultBooksFormatCubit>().state;
    final defaultTags = context.read<DefaultBookTagsCubit>().state;

    final book = Book(
      title: item.displayTitle,
      author: item.displayAuthor,
      status: widget.status,
      favourite: false,
      description: work?.workDescription,
      publicationYear: item.year,
      bookFormat: defaultBookFormat,
      readings: List<Reading>.empty(growable: true),
      tags: defaultTags.isNotEmpty ? defaultTags.join('|||||') : null,
      dateAdded: DateTime.now(),
      dateModified: DateTime.now(),
    );

    if (!mounted) return;

    context.read<EditBookCubit>().setBook(book);

    // Determine cover URL
    String? coverUrl;
    if (work != null) {
      coverUrl = FantLabService.getWorkCoverUrl(work);
    }
    coverUrl ??= FantLabService.getCoverUrl(item);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBookScreen(
          fromFantLab: true,
          fantLabCoverUrl: coverUrl,
        ),
      ),
    );
  }

  // Used when search results are empty
  void _addBookManually() {
    FocusManager.instance.primaryFocus?.unfocus();

    final book = Book(
      title: _searchController.text,
      author: '',
      status: BookStatus.read,
      readings: List<Reading>.empty(growable: true),
      tags: 'owned',
      dateAdded: DateTime.now(),
      dateModified: DateTime.now(),
    );

    context.read<EditBookCubit>().setBook(book);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddBookScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pagingController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return KeyboardDismissible(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            LocaleKeys.search_in_fantlab.tr(),
            style: const TextStyle(fontSize: 18),
          ),
        ),
        body: Column(
          children: [
            _buildSearchField(context),
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Divider(height: 3),
            ),
            searchActivated
                ? Expanded(child: _buildSearchResults())
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Scrollbar _buildSearchResults() {
    return Scrollbar(
      child: PagingListener(
        controller: _pagingController,
        builder: (context, state, fetchNextPage) =>
            PagedListView<int, FLSearchResultWork>(
          state: state,
          fetchNextPage: fetchNextPage,
          builderDelegate: PagedChildBuilderDelegate<FLSearchResultWork>(
            firstPageProgressIndicatorBuilder: (_) =>
                _buildProgressIndicator(context),
            newPageProgressIndicatorBuilder: (_) =>
                _buildNewPageProgressIndicator(context),
            noItemsFoundIndicatorBuilder: (_) => _buildNoItemsFoundIndicator(),
            itemBuilder: (context, item, index) => _buildResultCard(item),
          ),
        ),
      ),
    );
  }

  Center _buildProgressIndicator(BuildContext context) {
    return Center(
      child: Platform.isIOS
          ? CupertinoActivityIndicator(
              radius: 20,
              color: Theme.of(context).colorScheme.primary,
            )
          : LoadingAnimationWidget.staggeredDotsWave(
              color: Theme.of(context).colorScheme.primary,
              size: 42,
            ),
    );
  }

  Center _buildNewPageProgressIndicator(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Platform.isIOS
            ? CupertinoActivityIndicator(
                radius: 20,
                color: Theme.of(context).colorScheme.primary,
              )
            : LoadingAnimationWidget.staggeredDotsWave(
                color: Theme.of(context).colorScheme.primary,
                size: 42,
              ),
      ),
    );
  }

  Widget _buildResultCard(FLSearchResultWork item) {
    return BookCardFL(
      title: item.displayTitle,
      subtitle: item.name != null &&
              item.rusname != null &&
              item.name!.isNotEmpty &&
              item.rusname!.isNotEmpty &&
              item.name != item.rusname
          ? item.name
          : null,
      author: item.displayAuthor,
      coverUrl: FantLabService.getCoverUrl(item),
      year: item.year,
      workType: item.workTypeNameShow,
      rating: item.midmark,
      markcount: item.markcount,
      onAddBookPressed: () => _onAddBookPressed(item),
    );
  }

  Center _buildNoItemsFoundIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(cornerRadius),
            onTap: _addBookManually,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Text(
                    LocaleKeys.no_search_results.tr(),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    LocaleKeys.click_to_add_book_manually.tr(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Padding _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 10, 5),
      child: Row(
        children: [
          Expanded(
            child: BookTextField(
              controller: _searchController,
              keyboardType: TextInputType.name,
              maxLength: 99,
              autofocus: true,
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _startNewSearch(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _startNewSearch,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(cornerRadius),
                ),
              ),
              child: Text(
                LocaleKeys.search.tr(),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
