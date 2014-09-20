function expand(item) {
    item.addClass('fa-caret-down')
        .removeClass('fa-caret-right')
        .parent().next().slideDown('fast');
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
})
