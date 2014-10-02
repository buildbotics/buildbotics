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


function expand_current(instant) {
    var target = $('#toc a[href="' + window.location.hash + '"]');
    if (target.length) {
        var li = target.parent().parent().parent();
        if (li.get(0).tagName == 'LI') target = li;

        target = target.find('.fa')[0];

        if (instant) $(target).parent().next().show();
        expand($(target));
    }
}


$(function() {
    // Table of Contents
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

    $('#toc > ul > li > a').click(function () {
        expand($(this).find('span'));
    });

    // Expand current hashtag
    expand_current(true);

    // Scrolling
    var offsets = [];
    $('#content h1, #content h2').each(function() {
        offsets.push({
            top: $(this).offset().top,
            id: $(this).attr('id')
        });
    });

    $(document).bind('scroll', function() {
        var last;
        var offset = window.pageYOffset + window.innerHeight / 8;

        for (var i = 0; i < offsets.length; i++) {
            if (offset < offsets[i].top) {
                if (typeof last != 'undefined' &&
                    window.location.hash != ('#' + last)) {
                    var scroll = $('html, body').scrollTop();
                    window.location.hash = last;
                    $('html, body').scrollTop(scroll);
                    expand_current();
                }

                break;
            }

            last = offsets[i].id;
        }
    });

    // Links
    $('#content a').click(function () {
        setTimeout(expand_current, 100);
    });
})
