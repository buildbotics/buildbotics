function expand(item) {
    item.addClass('fa-caret-down')
        .removeClass('fa-caret-right')
        .parent().next().slideDown('fast');

    $('#toc .fa-caret-down').each(function () {
        if (!$(this).is(item)) collapse($(this));
    });
}


function collapse(item) {
    item.removeClass('fa-caret-down')
        .addClass('fa-caret-right')
        .parent().next().slideUp('fast');
}


$(function() {
    $('<span>')
        .addClass('fa fa-caret-right')
        .click(function (e) {
            var expanded = $(this).hasClass('fa-caret-down');

            if (expanded) collapse($(this));
            else expand($(this));

            e.preventDefault();
            e.stopPropagation();
        })
        .prependTo('#toc > ul > li > a');

    $('#toc > ul > li > a').click(function (e) {
        expand($(this).find('span'));
    });

    // Expand current hashtag
    var target = $('#toc a[href="' + window.location.hash + '"]');
    if (target.length) {
        var li = target.parent().parent().parent();
        if (li.get(0).tagName == 'LI') target = li;

        target = target.find('.fa')[0];

        $(target).parent().next().show();
        expand($(target));
    }
})
