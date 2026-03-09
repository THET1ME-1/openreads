import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openreads/generated/locale_keys.g.dart';
import 'package:openreads/logic/cubit/current_book_cubit.dart';
import 'package:openreads/logic/cubit/selected_books_cubit.dart';
import 'package:openreads/main.dart';
import 'package:openreads/model/book.dart';
import 'package:openreads/ui/book_screen/book_screen.dart';
import 'package:openreads/ui/books_screen/widgets/widgets.dart';

class SimiliarBooksScreen extends StatefulWidget {
  const SimiliarBooksScreen({
    super.key,
    this.tag,
    this.author,
  });

  final String? tag;
  final String? author;

  @override
  State<SimiliarBooksScreen> createState() => _SimiliarBooksScreenState();
}

class _SimiliarBooksScreenState extends State<SimiliarBooksScreen> {
  @override
  void initState() {
    if (widget.tag != null) {
      bookCubit.getBooksWithSameTag(widget.tag!);
    } else if (widget.author != null) {
      bookCubit.getBooksWithSameAuthor(widget.author!);
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            widget.tag != null
                ? const SizedBox()
                : widget.author != null
                    ? Text(
                        '${LocaleKeys.author.tr()}: ',
                        style: const TextStyle(fontSize: 18),
                      )
                    : const SizedBox(),
            widget.tag != null
                ? _buildTag(widget.tag!)
                : widget.author != null
                    ? Text(
                        widget.author!,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      )
                    : const SizedBox(),
          ],
        ),
      ),
      body: StreamBuilder(
          stream: widget.tag != null
              ? bookCubit.booksWithSameTag
              : bookCubit.booksWithSameAuthor,
          builder: (context, AsyncSnapshot<List<Book>?> snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final books = snapshot.data!;
              if (books.isEmpty) {
                return Center(
                  child: Text(LocaleKeys.this_list_is_empty_1.tr()),
                );
              }
              return _buildBooksList(books);
            } else if (snapshot.hasError) {
              return Text(
                snapshot.error.toString(),
              );
            } else {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
          }),
    );
  }

  Widget _buildBooksList(List<Book> books) {
    return BlocBuilder<SelectedBooksCubit, List<int>>(
      builder: (context, selectedList) {
        final multiSelectMode = selectedList.isNotEmpty;
        return ListView.builder(
          itemCount: books.length,
          itemBuilder: (context, index) {
            final heroTag = 'tag_similar_${books[index].id}';
            Color? color =
                multiSelectMode && selectedList.contains(books[index].id)
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : null;
            return BookCardList(
              book: books[index],
              heroTag: heroTag,
              cardColor: color,
              addBottomPadding: (books.length == index + 1),
              onPressed: () {
                if (books[index].id == null) return;
                if (multiSelectMode) {
                  context
                      .read<SelectedBooksCubit>()
                      .onBookPressed(books[index].id!);
                  return;
                }
                context.read<CurrentBookCubit>().setBook(books[index]);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookScreen(heroTag: heroTag),
                  ),
                );
              },
              onLongPressed: () {
                if (books[index].id == null) return;
                context
                    .read<SelectedBooksCubit>()
                    .onBookPressed(books[index].id!);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTag(String tag) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: FilterChip(
        label: Text(
          tag,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          maxLines: 1,
        ),
        clipBehavior: Clip.none,
        onSelected: (_) {},
      ),
    );
  }
}
